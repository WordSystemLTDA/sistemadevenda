import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/acoes_menu_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/alterar_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/menu_pedido_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delivery_test.dart' show ServicoDeliveryTeste, pedidoTeste;

class _ServicoAlteracao extends ServicoDeliveryTeste {
  bool recusarAlteracao = false;
  final tentativas = <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>> acao(String acao, PedidoDelivery pedido,
      [Map<String, dynamic> campos = const {}]) async {
    if (acao == 'pagamentos') {
      return {
        'sucesso': true,
        'dados': {
          'pagamentos': [
            {'id': '71', 'valor': '21.00', 'documento': 'Pix'},
          ],
        },
      };
    }
    if (acao == 'alterarPagamento') {
      tentativas.add(Map<String, dynamic>.from(campos));
      if (recusarAlteracao) {
        throw StateError('O pagamento mudou. Consulte novamente.');
      }
    }
    return super.acao(acao, pedido, campos);
  }

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'tela_nfe_saida/listar_bancos.php') {
      return {
        'ativoBancoPix': 'Sim',
        'nomeBancoPix': 'Pix',
        'idBancoPix': '10',
      };
    }
    return super.consultar(rota, campos);
  }
}

Future<void> _abrirAlteracao(
  WidgetTester tester,
  _ServicoAlteracao servico, {
  required void Function(bool?) aoFechar,
}) async {
  final pedido = pedidoTeste(campos: {
    'valorVenda': '21.00',
    'somaValorHistorico': '21.00',
  });
  await tester.pumpWidget(MaterialApp(
    home: Builder(builder: (context) {
      return Scaffold(
        body: TextButton(
          onPressed: () async {
            aoFechar(await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => AlterarPedidoDelivery(
                servico: servico,
                pedido: pedido,
                alteracao: AlteracaoDelivery.pagamento,
              ),
            ));
          },
          child: const Text('Alterar pagamento'),
        ),
      );
    }),
  ));
  await tester.tap(find.text('Alterar pagamento'));
  await tester.pumpAndSettle();
}

Future<void> _selecionarDinheiro(WidgetTester tester) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Dinheiro').last);
  await tester.pumpAndSettle();
}

void main() {
  for (final largura in [320.0, 1180.0]) {
    testWidgets('troca confirmada fecha automaticamente em ${largura}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(largura, 900);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final servico = _ServicoAlteracao();
      addTearDown(servico.usuario.dispose);
      bool? resultado;
      await _abrirAlteracao(tester, servico,
          aoFechar: (valor) => resultado = valor);
      await _selecionarDinheiro(tester);
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();

      expect(resultado, isTrue);
      expect(find.byType(AlterarPedidoDelivery), findsNothing);
      expect(servico.tentativas, [
        {'movimentacao': '71', 'banco': '1', 'valorOriginal': '21.00'},
      ]);
      expect(servico.gravacoes.single.$1, 'delivery/acoes_pedido.php');
      expect(servico.gravacoes.single.$2['acao'], 'alterarPagamento');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('recusa conserva a troca selecionada e permite nova tentativa',
      (tester) async {
    final servico = _ServicoAlteracao()..recusarAlteracao = true;
    addTearDown(servico.usuario.dispose);
    bool? resultado;
    await _abrirAlteracao(tester, servico,
        aoFechar: (valor) => resultado = valor);
    await _selecionarDinheiro(tester);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlterarPedidoDelivery), findsOneWidget);
    expect(find.text('O pagamento mudou. Consulte novamente.'), findsOneWidget);
    expect(find.text('Dinheiro'), findsOneWidget);
    expect(resultado, isNull);
    expect(servico.gravacoes, isEmpty);

    servico.recusarAlteracao = false;
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(resultado, isTrue);
    expect(servico.tentativas, hasLength(2));
    expect(servico.gravacoes, hasLength(1));
    expect(find.byType(AlterarPedidoDelivery), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('voltar da troca nao altera nem exclui o recebimento',
      (tester) async {
    final servico = _ServicoAlteracao();
    addTearDown(servico.usuario.dispose);
    bool fechou = false;
    bool? resultado;
    await _abrirAlteracao(tester, servico, aoFechar: (valor) {
      fechou = true;
      resultado = valor;
    });
    await _selecionarDinheiro(tester);
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    expect(fechou, isTrue);
    expect(resultado, isNull);
    expect(servico.tentativas, isEmpty);
    expect(servico.gravacoes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('alterar pedido sem recebimento abre o pagamento habilitado',
      (tester) async {
    final servico = _ServicoAlteracao()
      ..atual = pedidoTeste(campos: {
        'valorVenda': '21.00',
        'somaValorHistorico': '0.00',
      });
    addTearDown(servico.usuario.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        return Scaffold(
          body: TextButton(
            onPressed: () => executarAcaoDelivery(
              context,
              servico,
              servico.atual,
              AcaoPedidoDelivery.pagamento,
            ),
            child: const Text('Alterar pagamento'),
          ),
        );
      }),
    ));
    await tester.tap(find.text('Alterar pagamento'));
    await tester.pumpAndSettle();

    expect(find.text('Receber pagamento'), findsOneWidget);
    expect(find.textContaining('A receber'), findsOneWidget);
    final confirmar = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirmar'),
    );
    expect(confirmar.onPressed, isNotNull);
    expect(servico.gravacoes, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
  });
}
