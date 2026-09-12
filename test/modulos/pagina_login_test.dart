import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
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

class ModuloLoginTeste extends Module {
  final autenticacao = AutenticacaoSemResposta();
  final servidor = ServidorSemResposta();

  @override
  void binds(Injector i) {
    i.addInstance<ServicoAutenticacao>(autenticacao);
    i.addInstance<Server>(servidor);
  }
}

void main() {
  late ModuloLoginTeste modulo;
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'usuario': jsonEncode({'id': '1', 'email': 'teste', 'senha': 'teste'}),
      'conexao':
          jsonEncode({'tipoConexao': 'local', 'servidor': '', 'porta': ''}),
    });
    modulo = ModuloLoginTeste();
    Modular.init(modulo);
  });
  tearDown(() {
    modulo.servidor.dispose();
    Modular.destroy();
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
