import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/menu_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delivery_test.dart';

PedidoDelivery pedidoOnline(
        {String tipo = '5',
        String status = 'pending',
        bool liberado = false,
        Map<String, dynamic> campos = const {}}) =>
    pedidoTeste(campos: {
      'pagamento_online_obrigatorio': true,
      'pagamento_online_liberado': liberado,
      'pagamento_online_status': status,
      'pagamento_online_tipo': tipo,
      ...campos,
    });

void main() {
  for (final tipo in ['5', '6']) {
    test('MP $tipo nunca libera preparo por pagamento manual ou Pagar Depois',
        () {
      for (final status in [
        'pending',
        'in_process',
        'authorized',
        'rejected',
        'cancelled',
        'refunded',
        'charged_back',
        'partially_refunded',
        ''
      ]) {
        final pedido = pedidoOnline(
            tipo: tipo,
            status: status,
            liberado: true,
            campos: {'pagamentoPendente': true, 'somaValorHistorico': '86.00'});
        expect(pedido.aguardandoPagamentoOnline, isTrue, reason: status);
        expect(pedido.pagamentoConcluido, isFalse);
        expect(pedido.podeAvancar(etapasTeste().first), isFalse);
        for (final receberNoFinal in [false, true]) {
          expect(
              ConfigDelivery(receberNoFinal: receberNoFinal)
                  .exigePagamento(pedido, etapasTeste().last),
              isFalse);
        }
      }
      expect(
          pedidoOnline(tipo: tipo, status: 'approved')
              .aguardandoPagamentoOnline,
          isTrue);
      expect(
          pedidoOnline(tipo: tipo, status: 'approved', liberado: true)
              .podeAvancar(etapasTeste().first),
          isTrue);
    });

    test(
        'MP $tipo bloqueia gravacao direta de etapa e finalizacao antes do HTTP',
        () async {
      final servico = ServicoDeliveryTeste();
      final pedido = pedidoOnline(tipo: tipo);
      await expectLater(
          servico.avancar(pedido, etapasTeste()[1]), throwsStateError);
      await expectLater(servico.concluir(pedido), throwsStateError);
      expect(servico.gravacoes, isEmpty);
    });

    for (final ambos in [false, true]) {
      test('MP $tipo bloqueia geracao do preparo; ambos: $ambos', () async {
        final servico = ServicoDeliveryTeste();
        await expectLater(
          ImpressaoDelivery.prepararMensagens(servico, pedidoOnline(tipo: tipo),
              preparo: !ambos, ambos: ambos),
          throwsStateError,
        );
        expect(servico.gravacoes, isEmpty);
      });
    }

    for (final largura in [320.0, 1180.0]) {
      testWidgets(
          'MP $tipo em $largura fica visivel e bloqueado, polling approved libera sem caixa',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(largura, 800);
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final servico = ServicoDeliveryTeste()
          ..atual = pedidoOnline(tipo: tipo);
        servico.respostaLista = () async => [
              EtapaDelivery.fromMap({
                'id': '1',
                'nomeOpcao': 'Aguardando',
                'nomeBotao': 'Preparar',
                'tipodeimpressao': '0',
                'vendas':
                    servico.atual.etapa == '1' ? [servico.atual.dados] : []
              }),
              EtapaDelivery.fromMap({
                'id': '2',
                'nomeOpcao': 'Em preparo',
                'nomeBotao': 'Pronto',
                'tipodeimpressao': '1',
                'vendas':
                    servico.atual.etapa == '2' ? [servico.atual.dados] : []
              }),
            ];
        final provedor = ProvedorDelivery(servico);
        addTearDown(provedor.dispose);
        var recebimentos = 0;
        await tester.pumpWidget(MaterialApp(
            home: PaginaDelivery(
                provedor: provedor,
                receberPedido: (_) async {
                  recebimentos++;
                  return true;
                })));
        await tester.pumpAndSettle();
        final botao = find.byKey(const ValueKey('avancar-delivery-25'));
        expect(botao, findsOneWidget);
        expect(tester.widget<FilledButton>(botao).onPressed, isNull);
        expect(find.text('Aguardando pagamento'), findsOneWidget);
        expect(servico.gravacoes, isEmpty);
        servico.atual = pedidoOnline(
            tipo: tipo,
            status: 'approved',
            liberado: true,
            campos: {'somaValorHistorico': '86.00'});
        await tester.pump(const Duration(seconds: 6));
        await tester.pumpAndSettle();
        expect(tester.widget<FilledButton>(botao).onPressed, isNotNull);
        await tester.ensureVisible(botao);
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(servico.atual.etapa, '2');
        expect(
            servico.gravacoes
                .where((g) => g.$1 == 'delivery/mudar_status_delivery.php'),
            hasLength(1));
        expect(recebimentos, 0);
        expect(
            servico.gravacoes.where((g) => g.$1 == 'delivery/pagar_pedido.php'),
            isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  test(
      'status canonico da API prevalece sobre pagamento local antigo apos estorno',
      () async {
    final servico = ServicoDeliveryTeste();
    final pago = pedidoOnline(
        status: 'approved',
        liberado: true,
        campos: {'somaValorHistorico': '86.00'});
    servico.atual = pago;
    servico.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': '1',
            'vendas': [servico.atual.dados]
          })
        ];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.atualizarPedido(pago);
    servico.atual = pedidoOnline(status: 'refunded');
    await provedor.listar();
    expect(provedor.etapas.single.pedidos.single.aguardandoPagamentoOnline,
        isTrue);
    expect(provedor.etapas.single.pedidos.single.pago, 0);
  });

  testWidgets('menu MP nao oferece receber, editar valor nem preparo pendente',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => mostrarMenuPedidoDelivery(
                      context, pedidoOnline(), etapasTeste().first),
                  child: const Text('Opções'),
                )))));
    await tester.tap(find.text('Opções'));
    await tester.pumpAndSettle();
    expect(find.text('Concluir Pagamento'), findsNothing);
    expect(find.text('Mudar Forma de Pagamento'), findsNothing);
    expect(find.text('Imprimir Preparo'), findsNothing);
    expect(find.text('Ver Pedido'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'modal recebimento aberta por rota antiga nao cobra MP manualmente',
      (tester) async {
    final servico = ServicoDeliveryTeste()..atual = pedidoOnline();
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
    expect(servico.gravacoes, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('resposta antiga sem metadata MP conserva forma comum', () {
    final pedido = pedidoTeste();
    expect(pedido.aguardandoPagamentoOnline, isFalse);
    expect(pedido.podeAvancar(etapasTeste().first), isTrue);
    expect(const ConfigDelivery().exigePagamento(pedido, etapasTeste().last),
        isTrue);
  });
}
