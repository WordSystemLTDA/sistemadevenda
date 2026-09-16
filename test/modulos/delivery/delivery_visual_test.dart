import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../suporte/captura_tela.dart';
import 'delivery_test.dart';

void main() {
  setUpAll(carregarFontesDeTeste);
  testWidgets('avanca uma vez para o ID da proxima etapa configurada',
      (tester) async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar preparo').first);
    await tester.pumpAndSettle();
    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$1, 'delivery/mudar_status_delivery.php');
    expect(s.gravacoes.single.$2['status'], '2');
    expect(s.gravacoes.single.$2['irParaProximo'], isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('cancelar pagamento nao avanca o pedido', (tester) async {
    final s = ServicoDeliveryTeste()..config = const ConfigDelivery();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Receber R\$').first);
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
      expect(find.byTooltip('Novo pedido'), findsOneWidget);
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
      await capturarTela(tester, 'delivery_novo_$nome');
      await tester.tap(find.text('Abrir cardápio'));
      await tester.pumpAndSettle();
      expect(s.gravacoes, isEmpty);
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
