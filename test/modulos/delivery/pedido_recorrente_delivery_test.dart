import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../suporte/captura_tela.dart';
import 'delivery_test.dart';

void main() {
  setUpAll(carregarFontesDeTeste);

  for (final (tamanho, escala, brilho) in [
    (const Size(320, 568), 1.0, Brightness.light),
    (const Size(430, 932), 1.0, Brightness.light),
    (const Size(820, 1180), 1.0, Brightness.light),
    (const Size(1180, 820), 1.0, Brightness.light),
    (const Size(320, 568), 1.6, Brightness.dark),
  ]) {
    final nome =
        '${tamanho.width.toInt()}x${tamanho.height.toInt()}-$escala-${brilho.name}';
    testWidgets('pedido recorrente discreto e tempo junto ao menu em $nome',
        (tester) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool? recorrente;
      final servico = ServicoDeliveryTeste()
        ..respostaLista = () async => [
              EtapaDelivery.comPedidos(etapasTeste().first, [
                pedidoTeste(campos: {
                  'id': '7',
                  'numeroPedido': '7',
                  'origemPedido': 'painel',
                  'recorrenteVinculado': recorrente,
                  'nomeCliente': 'Cliente com nome completo para entrega',
                }),
              ]),
            ];
      final provedor = ProvedorDelivery(servico);
      addTearDown(provedor.dispose);
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                  seedColor: const Color(0xFF6651A7), brightness: brilho)),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: PaginaDelivery(provedor: provedor),
        ),
      ));
      await tester.pumpAndSettle();

      for (final valor in [null, false, true]) {
        recorrente = valor;
        await provedor.listar();
        await tester.pumpAndSettle();
        expect(find.text('Recorrente'),
            valor == true ? findsOneWidget : findsNothing);
        expect(find.byTooltip('Pedido gerado por recorrência'),
            valor == true ? findsOneWidget : findsNothing);
        expect(find.text('#7 · Painel'), findsOneWidget);
        expect(find.byTooltip('Origem do pedido: Painel'), findsOneWidget);
        expect(find.text('Entrega · 2 itens'), findsOneWidget);
        final tempo =
            tester.getRect(find.byKey(const ValueKey('tempo-delivery-7')));
        final menu = tester.getRect(find.byTooltip('Opções do pedido #7'));
        expect(tempo.right, lessThanOrEqualTo(menu.left));
        expect(menu.left - tempo.right, lessThanOrEqualTo(8));
        expect(tempo.center.dy, closeTo(menu.center.dy, 1));
        expect(tester.takeException(), isNull);
      }
      expect(servico.gravacoes, isEmpty);
      await capturarTela(tester, 'delivery_recorrente_$nome');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    });
  }
}
