import 'dart:async';

import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/filtros_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'delivery_test.dart';

PedidoDelivery _pedido(String id, String abertura, {String etapa = '1'}) =>
    pedidoTeste(campos: {
      'id': id,
      'nomeCliente': 'Cliente $id',
      'numeroPedido': '5',
      'dataAbertura': abertura,
      'idopcoescarrossel': etapa,
    });

EtapaDelivery _etapa(String id, List<PedidoDelivery> pedidos) =>
    EtapaDelivery.fromMap({
      'id': id,
      'nomeOpcao': 'Etapa $id',
      'vendas': pedidos.map((pedido) => pedido.dados).toList(),
    });

List<EtapaDelivery> _etapas() => [
      for (final id in ['1', '2', '3', '4'])
        _etapa(id, [
          _pedido('${id}00', '2026-10-04T10:00:00', etapa: id),
          _pedido('${id}9', '2026-10-04T12:00:00', etapa: id),
          _pedido('${id}50', '2026-10-04T11:00:00', etapa: id),
        ]),
    ];

List<String> _ids(EtapaDelivery etapa) =>
    etapa.pedidos.map((pedido) => pedido.id).toList();

void main() {
  test('mais recente é padrão em todas as etapas, pela abertura do pedido',
      () async {
    final origem = _etapas();
    final servico = ServicoDeliveryTeste()..respostaLista = () async => origem;
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();

    expect(provedor.ordenacao, OrdenacaoPedidosDelivery.maisRecente);
    expect(provedor.etapas.map((etapa) => etapa.id), ['1', '2', '3', '4']);
    for (final etapa in provedor.etapas) {
      expect(_ids(etapa), ['${etapa.id}9', '${etapa.id}50', '${etapa.id}00']);
    }
    expect(_ids(origem.first), ['100', '19', '150']);
  });

  test('mais antigo reordena todas as etapas imediatamente e após atualização',
      () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => _etapas();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.ordenacao = OrdenacaoPedidosDelivery.maisAntigo;

    expect(servico.consultas, 1);
    for (final etapa in provedor.etapas) {
      expect(_ids(etapa), ['${etapa.id}00', '${etapa.id}50', '${etapa.id}9']);
    }
    await provedor.listar();
    expect(provedor.ordenacao, OrdenacaoPedidosDelivery.maisAntigo);
    expect(_ids(provedor.etapas.first), ['100', '150', '19']);
  });

  test('desempata horário igual por código numérico mesmo com número repetido',
      () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [
            _etapa('1', [
              for (final id in ['9', '100', '10'])
                _pedido(id, '2026-10-04T12:00:00'),
            ]),
          ];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    expect(_ids(provedor.etapas.single), ['100', '10', '9']);
    provedor.ordenacao = OrdenacaoPedidosDelivery.maisAntigo;
    expect(_ids(provedor.etapas.single), ['9', '10', '100']);
  });

  test('ordena rascunhos locais e mantém datas inválidas ao fim', () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [
            _etapa('local', [
              _pedido('delivery-local:antigo', '2026-10-04T10:00:00',
                  etapa: 'local'),
              _pedido('delivery-local:novo', '2026-10-04T12:00:00',
                  etapa: 'local'),
            ]),
            _etapa('1', [
              _pedido('10', ''),
              _pedido('9', '2026-10-04T12:00:00'),
              _pedido('100', 'inválida'),
            ]),
          ];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    expect(_ids(provedor.etapas.first),
        ['delivery-local:novo', 'delivery-local:antigo']);
    expect(_ids(provedor.etapas.last), ['9', '100', '10']);
    provedor.ordenacao = OrdenacaoPedidosDelivery.maisAntigo;
    expect(_ids(provedor.etapas.first),
        ['delivery-local:antigo', 'delivery-local:novo']);
    expect(_ids(provedor.etapas.last), ['9', '10', '100']);
  });

  for (final ordenacao in OrdenacaoPedidosDelivery.values) {
    test(
        'novo pedido notificado e resposta atrasada respeitam ${ordenacao.rotulo}',
        () async {
      final servico = ServicoDeliveryTeste()
        ..respostaLista = () async => _etapas();
      final provedor = ProvedorDelivery(servico)..ordenacao = ordenacao;
      addTearDown(provedor.dispose);
      await provedor.listar();
      provedor.atualizarPedido(_pedido('8', '2026-10-04T13:00:00'));
      final esperados = ordenacao == OrdenacaoPedidosDelivery.maisRecente
          ? ['8', '19', '150', '100']
          : ['100', '150', '19', '8'];
      expect(_ids(provedor.etapas.first), esperados);
      await provedor.listar();
      expect(_ids(provedor.etapas.first), esperados);
    });
  }

  test('pedido movido de etapa entra na posição correspondente à abertura',
      () async {
    final movido = _pedido('50', '2026-10-04T11:00:00');
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [
            _etapa('1', [movido]),
            _etapa('2', [
              _pedido('200', '2026-10-04T10:00:00', etapa: '2'),
              _pedido('29', '2026-10-04T12:00:00', etapa: '2'),
            ]),
          ];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.moverPedidoParaEtapa(movido, '2');
    expect(provedor.etapas.first.pedidos, isEmpty);
    expect(_ids(provedor.etapas.last), ['29', '50', '200']);
    await provedor.listar();
    expect(_ids(provedor.etapas.last), ['29', '50', '200']);
    provedor.ordenacao = OrdenacaoPedidosDelivery.maisAntigo;
    expect(_ids(provedor.etapas.last), ['200', '50', '29']);
  });

  test('consulta em andamento usa a ordenação escolhida ao receber o resultado',
      () async {
    final resposta = Completer<List<EtapaDelivery>>();
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () => resposta.future;
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    final consulta = provedor.listar();
    provedor.ordenacao = OrdenacaoPedidosDelivery.maisAntigo;
    resposta.complete(_etapas());
    await consulta;
    expect(_ids(provedor.etapas.first), ['100', '150', '19']);
  });

  testWidgets(
      'filtro aplica ordenação e preserva escolha ao mudar etapa e atualizar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => _etapas();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await tester
        .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
    await tester.pumpAndSettle();

    expect(find.text('Cliente 19'), findsOneWidget);
    await tester.tap(find.byTooltip('Filtrar e ordenar pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Ordenação'), findsOneWidget);
    final campo = find.byKey(const ValueKey('ordenacao-delivery'));
    expect(
        tester
            .widget<DropdownButtonFormField<OrdenacaoPedidosDelivery>>(campo)
            .initialValue,
        OrdenacaoPedidosDelivery.maisRecente);
    await tester.tap(campo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais antigo').last);
    await tester.pumpAndSettle();
    expect(provedor.ordenacao, OrdenacaoPedidosDelivery.maisRecente);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(provedor.ordenacao, OrdenacaoPedidosDelivery.maisAntigo);
    expect(find.text('Cliente 100'), findsOneWidget);

    await tester.tap(find.text('Etapa 2 (3)'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente 200'), findsOneWidget);
    await tester.tap(find.byTooltip('Atualizar pedidos'));
    await tester.pumpAndSettle();
    expect(find.text('Cliente 200'), findsOneWidget);
    await tester.tap(find.byTooltip('Filtrar e ordenar pedidos'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<DropdownButtonFormField<OrdenacaoPedidosDelivery>>(campo)
            .initialValue,
        OrdenacaoPedidosDelivery.maisAntigo);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'cancelar filtro não altera ordenação, período ou tipo de entrega',
      (tester) async {
    final provedor = ProvedorDelivery(ServicoDeliveryTeste());
    addTearDown(provedor.dispose);
    final periodo = provedor.periodo;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                    body: TextButton(
                  onPressed: () => showDialog<bool>(
                      context: context,
                      builder: (_) => FiltrosDelivery(provedor: provedor)),
                  child: const Text('Filtro'),
                )))));
    await tester.tap(find.text('Filtro'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ordenacao-delivery')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais antigo').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ontem'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(provedor.ordenacao, OrdenacaoPedidosDelivery.maisRecente);
    expect(provedor.periodo, periodo);
    expect(provedor.tipo, '0');
  });
}
