import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_modelo.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutenticacaoSemResposta extends Fake implements ServicoAutenticacao {
  final resposta = Completer<bool>();
  CancelToken? cancelamento;

  @override
  Future<bool> entrar(
    String? usuario,
    String? senha, {
    bool permitirSessaoSalva = false,
    CancelToken? cancelToken,
    Duration tempoLimite = const Duration(seconds: 8),
  }) {
    cancelamento = cancelToken;
    return resposta.future;
  }
}

class ServidorSemResposta extends Server {
  @override
  Future<bool> connect(String ip, String porta) async => false;
}

class AtualizacaoControlada extends Fake implements ServicoConfig {
  Completer<ConfigModelo>? _resposta;
  Completer<ConfigModelo> get resposta =>
      _resposta ??= Completer<ConfigModelo>();
  CancelToken? cancelamento;
  int chamadas = 0;

  @override
  Future<ConfigModelo> consultarAtualizacao({CancelToken? cancelToken}) {
    cancelamento = cancelToken;
    chamadas++;
    return resposta.future;
  }
}

class ModuloLoginTeste extends Module {
  final autenticacao = AutenticacaoSemResposta();
  final servidor = ServidorSemResposta();
  final atualizacao = AtualizacaoControlada();

  @override
  void binds(Injector i) {
    i.addInstance<ServicoAutenticacao>(autenticacao);
    i.addInstance<Server>(servidor);
    i.addInstance<ServicoConfig>(atualizacao);
  }
}

void main() {
  late ModuloLoginTeste modulo;
  const canalLinks = MethodChannel('plugins.flutter.io/url_launcher');
  final linksAbertos = <String>[];
  final configAtualizacao = ConfigModelo(
    versaoAppAndroid: '1.0.40',
    versaoAppIos: '1.0.41',
    linkAtualizacaoAndroid: 'https://loja.example/android',
    linkAtualizacaoIos: 'https://loja.example/ios',
    linkBaixarApk: '',
    nomeApp: '',
    anoApp: '',
    logoApp: '',
  );
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'usuario': jsonEncode({'id': '1', 'email': 'teste', 'senha': 'teste'}),
      'conexao':
          jsonEncode({'tipoConexao': 'local', 'servidor': '', 'porta': ''}),
    });
    modulo = ModuloLoginTeste();
    Modular.init(modulo);
    linksAbertos.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalLinks, (chamada) async {
      if (chamada.method == 'launch') {
        linksAbertos.add(chamada.arguments['url'] as String);
        expect(chamada.arguments['useSafariVC'], isFalse);
        expect(chamada.arguments['useWebView'], isFalse);
      }
      return true;
    });
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalLinks, null);
    modulo.servidor.dispose();
    Modular.destroy();
  });

  Future<void> mostrarLogin(WidgetTester tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(home: PaginaLogin()));
    await tester.pump();
  }

  testWidgets('atualiza sem login e evita cliques repetidos durante consulta',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await mostrarLogin(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar aplicativo'));
    await tester.pump();

    expect(find.text('Buscando atualização...'), findsOneWidget);
    expect(modulo.autenticacao.cancelamento, isNull);
    final botao = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Buscando atualização...'));
    expect(botao.onPressed, isNull);
    expect(modulo.atualizacao.chamadas, 1);
    modulo.atualizacao.resposta.complete(configAtualizacao);
    await tester.pumpAndSettle();

    expect(linksAbertos, ['https://loja.example/android']);
    expect(find.text('Atualizar aplicativo'), findsOneWidget);
    expect(find.byType(PaginaLogin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'atualização interrompe login automático e ignora resposta tardia',
      (tester) async {
    await mostrarLogin(tester);
    expect(find.text('Conectando ao Servidor Local...'), findsOneWidget);
    await tester.tap(find.text('Atualizar aplicativo'));
    await tester.pump();
    expect(modulo.autenticacao.cancelamento!.isCancelled, isTrue);

    modulo.autenticacao.resposta.complete(true);
    modulo.atualizacao.resposta.complete(configAtualizacao);
    await tester.pumpAndSettle();

    expect(linksAbertos, hasLength(1));
    expect(find.byType(PaginaLogin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha de internet informa o usuário e permite tentar novamente',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await mostrarLogin(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar aplicativo'));
    await tester.pump();
    modulo.atualizacao.resposta.completeError(StateError('Sem internet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Confira sua conexão com a internet'),
        findsOneWidget);
    expect(linksAbertos, isEmpty);
    await tester.tap(find.text('Atualizar aplicativo'));
    await tester.pumpAndSettle();
    expect(modulo.atualizacao.chamadas, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consulta sem resposta cancela em vez de bloquear o login',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await mostrarLogin(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Atualizar aplicativo'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 16));
    await tester.pumpAndSettle();

    expect(find.text('Buscando atualização...'), findsNothing);
    expect(modulo.atualizacao.cancelamento!.isCancelled, isTrue);
    expect(
        tester
            .widget<OutlinedButton>(
                find.widgetWithText(OutlinedButton, 'Entrar'))
            .onPressed,
        isNotNull);
    modulo.atualizacao.resposta.complete(configAtualizacao);
    await tester.pumpAndSettle();
    expect(linksAbertos, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('configuração cancela atualização sem abrir link atrasado',
      (tester) async {
    await mostrarLogin(tester);
    await tester.tap(find.text('Atualizar aplicativo'));
    await tester.pump();
    await tester.tap(find.text('Configurações'));
    await tester.pumpAndSettle();

    expect(modulo.atualizacao.cancelamento!.isCancelled, isTrue);
    modulo.atualizacao.resposta.complete(configAtualizacao);
    await tester.pumpAndSettle();
    expect(find.text('Configurar Conexão'), findsOneWidget);
    expect(linksAbertos, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login sem resposta libera formulario e cancela tentativa',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaginaLogin()));
    await tester.pump();
    expect(find.text('Conectando ao Servidor Local...'), findsOneWidget);
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('Conectando ao Servidor Local...'), findsNothing);
    expect(find.text('Entrar'), findsOneWidget);
    expect(modulo.autenticacao.cancelamento!.isCancelled, isTrue);
    modulo.autenticacao.resposta.complete(true);
    await tester.pump();
    expect(find.byType(PaginaLogin), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'configuracoes acessiveis durante conexao e resposta tardia ignorada',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PaginaLogin()));
    await tester.pump();
    await tester.tap(find.text('Configurações de conexão'));
    await tester.pumpAndSettle();
    expect(find.text('Configurar Conexão'), findsOneWidget);
    expect(modulo.autenticacao.cancelamento!.isCancelled, isTrue);
    modulo.autenticacao.resposta.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Configurar Conexão'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
