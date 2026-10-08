import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServidorConfiguracaoTeste extends Server {
  final chamadas = <(String, String)>[];
  Completer<bool>? resposta;
  int desconexoes = 0;

  @override
  Future<bool> connect(String ip, String porta) async {
    chamadas.add((ip, porta));
    return await resposta?.future ?? false;
  }

  @override
  Future<void> disconnect() async => desconexoes++;
}

class ModuloConfiguracaoTeste extends Module {
  final servidor = ServidorConfiguracaoTeste();
  final usuario = UsuarioProvedor();

  @override
  void binds(Injector i) {
    i.addInstance<Server>(servidor);
    i.addInstance<UsuarioProvedor>(usuario);
  }
}

void main() {
  late ModuloConfiguracaoTeste modulo;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'online',
        'servidor': '192.168.2.113',
        'porta': '9980',
      }),
    });
    modulo = ModuloConfiguracaoTeste();
    Modular.init(modulo);
  });

  tearDown(() {
    final resposta = modulo.servidor.resposta;
    if (resposta != null && !resposta.isCompleted) resposta.complete(false);
    modulo.servidor.dispose();
    modulo.usuario.dispose();
    Modular.destroy();
  });

  Future<void> abrir(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PaginaConfiguracao(),
            )),
            child: const Text('Abrir configurações'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Abrir configurações'));
    await tester.pumpAndSettle();
  }

  Future<void> salvar(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Salvar'));
    await tester.pumpAndSettle();
  }

  Future<Map<String, dynamic>> configuracaoSalva() async {
    final prefs = await SharedPreferences.getInstance();
    return jsonDecode(prefs.getString('conexao')!) as Map<String, dynamic>;
  }

  testWidgets('online salva sem aguardar o servidor local e mantem api39',
      (tester) async {
    modulo.servidor.resposta = Completer<bool>();
    await abrir(tester);
    await salvar(tester);

    expect(find.byType(PaginaConfiguracao), findsNothing);
    expect(modulo.servidor.chamadas, [('192.168.2.113', '9980')]);
    expect(modulo.servidor.desconexoes, 1);
    expect((await configuracaoSalva())['tipoConexao'], 'online');
    expect((await Apis().getConexao()).servidor,
        'https://bigchef.com.br/sistema/apis_restaurantes/api_restaurantes_venda/api39/');

    modulo.servidor.resposta!.complete(false);
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('online permite IP e porta vazios', (tester) async {
    await abrir(tester);
    await tester.enterText(
        find.widgetWithText(TextField, 'IP local (opcional)'), '');
    await tester.enterText(
        find.widgetWithText(TextField, 'Porta (opcional)'), '');
    await salvar(tester);

    expect(find.byType(PaginaConfiguracao), findsNothing);
    expect(modulo.servidor.chamadas, isEmpty);
    expect(modulo.servidor.desconexoes, 1);
    expect(await configuracaoSalva(), {
      'tipoConexao': 'online',
      'servidor': '',
      'porta': '',
    });
    expect((await Apis().getConexao()).tipoConexao, 'online');
    await tester.pumpWidget(const SizedBox());
  });

  for (final tipo in ['local', 'localhost']) {
    testWidgets('$tipo exige IP e porta e preserva a conexao local',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        'conexao': jsonEncode({
          'tipoConexao': tipo,
          'servidor': '',
          'porta': '',
        }),
      });
      await abrir(tester);
      await salvar(tester);

      expect(find.byType(PaginaConfiguracao), findsOneWidget);
      expect(find.text('Campos precisam ser preenchidos'), findsOneWidget);
      expect(modulo.servidor.chamadas, isEmpty);
      expect(modulo.servidor.desconexoes, 0);

      await tester.enterText(
          find.widgetWithText(TextField, 'IP do Servidor Local'),
          '192.168.2.113');
      await tester.enterText(find.widgetWithText(TextField, 'Porta'), '9980');
      await salvar(tester);

      expect(find.byType(PaginaConfiguracao), findsNothing);
      expect(modulo.servidor.chamadas, [('192.168.2.113', '9980')]);
      expect((await Apis().getConexao()).servidor,
          'http://192.168.2.113/sistema/apis_restaurantes/api_restaurantes_venda/api39/');
      expect(
          find.textContaining(
              'Não foi possível conectar ao servidor 192.168.2.113:9980'),
          findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
