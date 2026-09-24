import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../suporte/captura_tela.dart';
import 'delivery_test.dart';

class _ServicoLoteDelivery extends ServicoDeliveryTeste {
  final Map<String, PedidoDelivery> pedidos = {
    for (final pedido in [
      pedidoTeste(campos: {
        'id': '101',
        'numeroPedido': '101',
        'idopcoescarrossel': '1',
        'quantidadeprodutos': '1',
      }),
      pedidoTeste(campos: {
        'id': '102',
        'numeroPedido': '102',
        'idopcoescarrossel': '1',
        'quantidadeprodutos': '1',
      }),
      pedidoTeste(campos: {
        'id': '103',
        'numeroPedido': '103',
        'idopcoescarrossel': '1',
        'quantidadeprodutos': '0',
      }),
      pedidoTeste(campos: {
        'id': 'delivery-local:104',
        'numeroPedido': '104',
        'idopcoescarrossel': '1',
        'quantidadeprodutos': '1',
      }),
    ])
      pedido.id: pedido,
  };

  @override
  Future<List<EtapaDelivery>> listar({
    required DateTime inicio,
    required DateTime fim,
    required String horaInicio,
    required String horaFim,
    String pesquisa = '',
    String tipo = '0',
  }) async =>
      [
        EtapaDelivery.fromMap({
          'id': '1',
          'nomeOpcao': 'Recebidos',
          'nomeBotao': 'Iniciar preparo',
          'tipodeimpressao': '0',
          'vendas': [
            for (final pedido in pedidos.values)
              if (pedido.etapa == '1') pedido.dados,
          ],
        }),
        EtapaDelivery.fromMap({
          'id': '2',
          'nomeOpcao': 'Em preparo',
          'nomeBotao': 'Pronto',
          'tipodeimpressao': '0',
          'vendas': [
            for (final pedido in pedidos.values)
              if (pedido.etapa == '2') pedido.dados,
          ],
        }),
      ];

  @override
  Future<PedidoDelivery> pedido(String id) async => pedidos[id]!;

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    gravacoes.add((rota, campos));
    if (rota == 'delivery/mudar_status_delivery.php') {
      final id = '${campos['id']}';
      pedidos[id] = pedidos[id]!.comEtapa('${campos['status']}');
    }
    return {
      'sucesso': true,
      'dados': {'idDelivery': '${campos['id'] ?? ''}'},
    };
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  testWidgets('avanca uma vez para o ID da proxima etapa configurada',
      (tester) async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();
    final iniciarPreparo = find.text('Iniciar preparo').first;
    await tester.ensureVisible(iniciarPreparo);
    await tester.tap(iniciarPreparo);
    await tester.pumpAndSettle();
    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$1, 'delivery/mudar_status_delivery.php');
    expect(s.gravacoes.single.$2['status'], '2');
    expect(s.gravacoes.single.$2['irParaProximo'], isFalse);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('avanca somente os cards escolhidos no lote', (tester) async {
    final s = _ServicoLoteDelivery();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();

    expect(find.text('Selecionar todos (2)'), findsNothing);
    expect(find.byKey(const ValueKey('selecionar-delivery-101')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('modo-selecao-delivery')));
    await tester.pump();
    expect(find.text('Selecionar todos (2)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('selecionar-delivery-101')));
    await tester.pump();
    expect(find.text('Avançar selecionados (1)'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('avancar-selecionados-delivery-1')));
    await tester.pumpAndSettle();
    expect(find.text('Avançar 1 pedido?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    final mudancas = s.gravacoes
        .where(
            (registro) => registro.$1 == 'delivery/mudar_status_delivery.php')
        .toList();
    expect(mudancas, hasLength(1));
    expect(mudancas.single.$2['id'], '101');
    expect(mudancas.single.$2['status'], '2');
    expect(s.pedidos['102']!.etapa, '1');
    expect(s.pedidos['103']!.etapa, '1');
    expect(s.pedidos['delivery-local:104']!.etapa, '1');
    expect(find.textContaining('Selecionar todos'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('selecionar todos avanca somente os pedidos disponiveis',
      (tester) async {
    final s = _ServicoLoteDelivery();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('modo-selecao-delivery')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('selecionar-todos-delivery-1')));
    await tester.pump();
    expect(find.text('Avançar selecionados (2)'), findsOneWidget);
    expect(
        tester
            .widget<Checkbox>(
                find.byKey(const ValueKey('selecionar-delivery-101')))
            .value,
        isTrue);
    await tester
        .tap(find.byKey(const ValueKey('avancar-selecionados-delivery-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
    await tester.pumpAndSettle();

    final mudancas = s.gravacoes
        .where(
            (registro) => registro.$1 == 'delivery/mudar_status_delivery.php')
        .toList();
    expect(mudancas, hasLength(2));
    expect(
        mudancas.map((registro) => registro.$2['id']).toSet(), {'101', '102'});
    expect(s.pedidos['103']!.etapa, '1');
    expect(s.pedidos['delivery-local:104']!.etapa, '1');
    expect(tester.takeException(), isNull);
  });
  testWidgets('cancelar pagamento nao avanca o pedido', (tester) async {
    final s = ServicoDeliveryTeste()..config = const ConfigDelivery();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();
    final receber = find.textContaining('Receber R\$').first;
    await tester.ensureVisible(receber);
    await tester.tap(receber);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Receber pagamento'), findsOneWidget);
    await tester.tap(find.text('Fechar'));
    await tester.pumpAndSettle();
    expect(s.gravacoes, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(820, 1180),
    const Size(1180, 820)
  ]) {
    final nome = '${size.width.toInt()}x${size.height.toInt()}';
    Future<void> abrir(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('captura'),
          child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: const Color(0xFF67548B))),
              home: child)));
      await tester.pumpAndSettle();
    }

    testWidgets('carrossel de delivery em $nome', (tester) async {
      final s = ServicoDeliveryTeste();
      final p = ProvedorDelivery(s);
      addTearDown(p.dispose);
      await abrir(tester, PaginaDelivery(provedor: p));
      expect(find.byTooltip('Novo Delivery'), findsOneWidget);
      expect(find.text('Novo Delivery'), findsOneWidget);
      expect(
          find.byKey(const ValueKey('modo-selecao-delivery')), findsOneWidget);
      expect(find.textContaining('Selecionar todos'), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
      final novoDelivery = find.byKey(const ValueKey('novo-delivery'));
      final impressora =
          find.byKey(const ValueKey('botao_pendencias_impressao_delivery'));
      expect(impressora, findsOneWidget);
      final tamanhoBotao = tester.getSize(novoDelivery);
      expect(tamanhoBotao.height, greaterThanOrEqualTo(64));
      expect(tamanhoBotao.width, greaterThan(280));
      expect(
        tester.getCenter(novoDelivery).dx,
        closeTo(size.width / 2, 0.1),
      );
      expect(tester.getRect(impressora).left, lessThan(40));
      if (size.width >= 600) {
        expect(tester.getCenter(impressora).dy,
            closeTo(tester.getCenter(novoDelivery).dy, 3));
        expect(tester.getRect(impressora).right,
            lessThan(tester.getRect(novoDelivery).left));
      } else {
        expect(tester.getRect(impressora).bottom,
            lessThan(tester.getRect(novoDelivery).top));
      }
      expect(find.text('Bruno Masson'), findsWidgets);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'delivery_$nome');
      await tester.tap(find.byTooltip('Opções do pedido #1'));
      await tester.pumpAndSettle();
      expect(find.text('Editar Pedido'), findsOneWidget);
      expect(find.text('Clonar Completo'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'delivery_menu_$nome');
      await tester.tap(find.byTooltip('Fechar opções'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(Tab, 'Em preparo (1)'));
      await tester.tap(find.widgetWithText(Tab, 'Em preparo (1)'));
      await tester.pumpAndSettle();
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
      await tester.enterText(find.byType(TextField).first, 'Bruno');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(p.pesquisa, 'Bruno');
      await tester.tap(find.byTooltip('Filtrar período e entrega'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'delivery_filtros_$nome');
      await tester.pumpWidget(const SizedBox());
    });
    testWidgets('novo pedido valida entrega e permite retirada em $nome',
        (tester) async {
      final s = ServicoDeliveryTeste();
      await abrir(tester, PaginaNovoDelivery(servico: s));
      expect(find.text('Novo Cliente'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('novo-cliente'))).height,
          greaterThanOrEqualTo(48));
      expect(
          tester
              .getTopLeft(find.byKey(const ValueKey('selecionar-cliente')))
              .dy,
          lessThan(tester
              .getTopLeft(find.byKey(const ValueKey('novo-cliente')))
              .dy));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('novo-endereco')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Novo endereço'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('novo-endereco'))).height,
          greaterThanOrEqualTo(48));
      await capturarTela(tester, 'delivery_novo_$nome');
      await tester.tap(find.text('Abrir cardápio'));
      await tester.pumpAndSettle();
      expect(s.gravacoes, isEmpty);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('tipo-entrega-2')),
        -200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tipo-entrega-2')));
      await tester.pumpAndSettle();
      expect(find.text('Endereço de entrega'), findsNothing);
      expect(tester.takeException(), isNull);
    });
    testWidgets('pagamento mostra troco e salva uma vez em $nome',
        (tester) async {
      final s = ServicoDeliveryTeste();
      await abrir(
          tester,
          Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => receberDelivery(context, s, '25'),
                      child: const Text('Receber')))));
      await tester.tap(find.text('Receber'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '100');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'delivery_pagamento_$nome');
      final confirmar = find.widgetWithText(FilledButton, 'Confirmar');
      await tester.ensureVisible(confirmar);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(s.gravacoes, hasLength(1));
      expect(s.gravacoes.single.$2['valortroco'], '14.00');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
