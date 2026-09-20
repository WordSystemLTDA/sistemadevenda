import 'dart:convert';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    app.usuarioProvedor = UsuarioProvedor();
  });

  test('trata referencia de impressao sem assumir que ha elementos', () async {
    final server = Server();
    addTearDown(server.dispose);

    String mensagem(String id) => jsonEncode({
          'tipo': 'Comanda',
          'tipoImpressao': '1',
          'idRequisicao': id,
        });

    await server.enviarImpressoes([mensagem('pedido-com-separador')]);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'referenciaImpressaoOrigem': 'origem|pedido-com-separador',
    });
    expect(server.filaImpressao.itens, isEmpty);

    await server.enviarImpressoes([mensagem('pedido-sem-separador')]);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'referenciaImpressaoOrigem': 'pedido-sem-separador',
    });
    expect(server.filaImpressao.itens, isEmpty);

    await server.enviarImpressoes([mensagem('pedido-pendente')]);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'referenciaImpressaoOrigem': 'referencia-incompleta|',
    });
    expect(server.filaImpressao.itens.single.id, 'pedido-pendente');
  });

  testWidgets('pode mostrar outro aviso depois que o anterior foi removido',
      (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    final scaffoldMessenger = GlobalKey<ScaffoldMessengerState>();
    app.navigatorKey = navigator;
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navigator,
      scaffoldMessengerKey: scaffoldMessenger,
      home: const Scaffold(body: SizedBox()),
    ));

    var agora = DateTime(2026, 9, 20, 11);
    final server = Server(agora: () => agora);
    addTearDown(server.dispose);

    await server.enviarImpressoes([
      jsonEncode({
        'tipo': 'Comanda',
        'tipoImpressao': '1',
        'idRequisicao': 'primeiro-aviso',
      })
    ]);
    // Impede a retentativa de conexao de interferir no relogio do widget test.
    await server.disconnect();
    await tester.pump();
    expect(find.text('Impressão pendente. O atendimento pode continuar.'),
        findsOneWidget);
    scaffoldMessenger.currentState!.removeCurrentSnackBar();
    await tester.pump();

    agora = agora.add(const Duration(minutes: 2));
    await server.enviarImpressoes([
      jsonEncode({
        'tipo': 'Comanda',
        'tipoImpressao': '1',
        'idRequisicao': 'segundo-aviso',
      })
    ]);
    await tester.pump();

    expect(find.text('Impressão pendente. O atendimento pode continuar.'),
        findsOneWidget);
  });
}
