import 'package:app/src/modulos/delivery/paginas/widgets/menu_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'delivery_test.dart';

void main() {
  for (final largura in [320.0, 1180.0]) {
    for (final caso in ['cancelar', 'parcial', 'completo', 'quitado']) {
      testWidgets('etapa Finalizar Pagamento em $largura: $caso',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(largura, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final s = ServicoDeliveryTeste()
          ..atual = pedidoTeste(campos: {
            'idVenda': '78',
            'status': 'Finalizado',
            'idopcoescarrossel': '3',
            'pagamentoPendente': true,
            'somaValorHistorico': caso == 'quitado' ? '86,00' : '0,00',
            'lancamentos': [
              {'nome': 'Pagar depois - receber na entrega', 'valor': '86.00'}
            ],
          });
        s.respostaLista = () async => [
              EtapaDelivery.fromMap({
                'id': '3',
                'nomeOpcao': 'TRÂNSITO',
                'nomeBotao': 'ENTREGUE',
                'tipodeimpressao': '0',
                'vendas': s.atual.etapa == '3' ? [s.atual.dados] : []
              }),
              EtapaDelivery.fromMap({
                'id': '4',
                'nomeOpcao': 'ENTREGUE',
                'nomeBotao': '',
                'tipodeimpressao': '3',
                'vendas': s.atual.etapa == '4' ? [s.atual.dados] : []
              }),
            ];
        final p = ProvedorDelivery(s);
        addTearDown(p.dispose);
        var recebimentos = 0;
        await tester.pumpWidget(MaterialApp(
            home: PaginaDelivery(
                provedor: p,
                receberPedido: (pedido) async {
                  recebimentos++;
                  expect(pedido.restante, 86);
                  if (caso == 'cancelar') return false;
                  s.atual = PedidoDelivery.fromMap({
                    ...s.atual.dados,
                    'somaValorHistorico': caso == 'parcial' ? '40.00' : '86.00'
                  });
                  return true;
                })));
        await tester.pumpAndSettle();
        final botao = find.byKey(const ValueKey('avancar-delivery-25'));
        expect(
            find.descendant(
                of: botao,
                matching:
                    find.text(caso == 'quitado' ? 'ENTREGUE' : 'FINALIZAR')),
            findsOneWidget);
        await tester.ensureVisible(botao);
        await tester.tap(botao);
        await tester.pumpAndSettle();
        final movimentos = s.gravacoes
            .where((g) => g.$1 == 'delivery/mudar_status_delivery.php')
            .toList();
        expect(recebimentos, caso == 'quitado' ? 0 : 1);
        if (caso == 'quitado' || caso == 'completo') {
          expect(movimentos, hasLength(1));
          expect(movimentos.single.$2['status'], '4');
          expect(movimentos.single.$2['statusOrigem'], '3');
          expect(s.atual.etapa, '4');
        } else {
          expect(movimentos, isEmpty);
          expect(s.atual.etapa, '3');
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      });
    }
  }

  test(
      'Pagar Depois libera preparo, mas nunca dispensa pagamento na etapa final',
      () {
    final pendente = pedidoTeste(campos: {'pagamentoPendente': true});
    for (final receberNoFinal in [false, true]) {
      final config = ConfigDelivery(receberNoFinal: receberNoFinal);
      expect(config.exigePagamento(pendente, etapasTeste()[1]), isFalse);
      expect(config.exigePagamento(pendente, etapasTeste().last), isTrue);
      expect(
          config.exigePagamento(
              pedidoTeste(campos: {
                'somaValorHistorico': '86,00',
                'pagamentoPendente': true
              }),
              etapasTeste().last),
          isFalse);
    }
  });
  testWidgets('venda vinculada em Pagar Depois oferece Concluir Pagamento',
      (tester) async {
    final pedido = pedidoTeste(campos: {
      'idVenda': '78',
      'status': 'Finalizado',
      'pagamentoPendente': true,
      'lancamentos': [
        {'nome': 'Pagar depois - receber na entrega', 'valor': '86.00'}
      ],
    });
    AcaoPedidoDelivery? selecionada;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () async => selecionada =
                      await mostrarMenuPedidoDelivery(
                          context, pedido, etapasTeste().last),
                  child: const Text('Opcoes'),
                )))));
    await tester.tap(find.text('Opcoes'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Concluir Pagamento'), 160,
        scrollable: find.byType(Scrollable).last);
    expect(find.text('Concluir Pagamento'), findsOneWidget);
    await tester.ensureVisible(find.text('Concluir Pagamento'));
    await tester.tap(find.text('Concluir Pagamento'));
    await tester.pumpAndSettle();
    expect(selecionada, AcaoPedidoDelivery.receber);
  });

  test('recebimento aceita saldo pendente mesmo com venda ja vinculada',
      () async {
    final servico = ServicoDeliveryTeste();
    await servico.pagar(
        pedidoTeste(campos: {
          'idVenda': '78',
          'status': 'Finalizado',
          'pagamentoPendente': true
        }),
        1,
        86,
        chavePagamento: 'teste-pagar-depois');
    expect(servico.gravacoes.single.$1, 'delivery/pagar_pedido.php');
    expect(servico.gravacoes.single.$2['valorAPagar'], '86.00');
    expect(servico.gravacoes.single.$2['limpar_pagamentos_anteriores'], '0');
    expect(servico.gravacoes.single.$2['chavePagamento'], 'teste-pagar-depois');
  });

  testWidgets('modal recebe saldo de pedido encerrado sem limpar pagamentos',
      (tester) async {
    final servico = ServicoDeliveryTeste()
      ..atual = pedidoTeste(campos: {
        'idVenda': '78',
        'status': 'Finalizado',
        'pagamentoPendente': true
      });
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () =>
                      receberDelivery(context, servico, servico.atual.id),
                  child: const Text('Receber'),
                )))));
    await tester.tap(find.text('Receber'));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'A receber.*86,00')), findsOneWidget);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(servico.gravacoes, hasLength(1));
    expect(servico.gravacoes.single.$2['limpar_pagamentos_anteriores'], '0');
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final caso in ['quitado', 'cancelado', 'parcial']) {
    testWidgets('menu financeiro preserva pedido $caso', (tester) async {
      final pedido = pedidoTeste(campos: {
        'idVenda': '78',
        'status': caso == 'cancelado' ? 'Cancelado' : 'Finalizado',
        'somaValorHistorico': caso == 'quitado' ? '86,00' : '40,00',
        'pagamentoPendente': caso != 'quitado',
      });
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => mostrarMenuPedidoDelivery(
                        context, pedido, etapasTeste().last),
                    child: const Text('Opcoes'),
                  )))));
      await tester.tap(find.text('Opcoes'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Financeiro'), 120,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Concluir Pagamento'),
          caso == 'parcial' ? findsOneWidget : findsNothing);
      await tester.scrollUntilVisible(
          find.text('Alterar Forma de Pagamento'), 100,
          scrollable: find.byType(Scrollable).last);
      expect(find.text('Alterar Forma de Pagamento'), findsOneWidget);
      if (caso == 'parcial') {
        final servico = ServicoDeliveryTeste();
        await servico.pagar(pedido, 4, 46);
        expect(servico.gravacoes.single.$2['valorAPagar'], '46.00');
        expect(
            servico.gravacoes.single.$2['limpar_pagamentos_anteriores'], '0');
      }
    });
  }
}
