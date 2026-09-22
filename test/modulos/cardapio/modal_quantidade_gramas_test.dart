import 'package:app/src/modulos/cardapio/paginas/widgets/modal_quantidade_gramas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('converte gramas em quilos e calcula pelo preco do quilo', () {
    const quantidade = QuantidadeProdutoPorPeso(200);

    expect(quantidade.quilos, closeTo(0.2, 0.0001));
    expect(quantidade.calcularTotal(45), closeTo(9, 0.0001));
  });

  testWidgets('modal continua utilizavel em tela estreita com texto ampliado',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    QuantidadeProdutoPorPeso? resultado;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.4)),
        child: child!,
      ),
      home: Builder(builder: (context) {
        return Scaffold(
          body: FilledButton(
            onPressed: () async {
              resultado = await showModalBottomSheet<QuantidadeProdutoPorPeso>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ModalQuantidadeGramas(
                  nomeProduto: 'Almoço por KG',
                  precoPorQuilo: 45,
                ),
              );
            },
            child: const Text('Abrir'),
          ),
        );
      }),
    ));

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('peso_gramas_campo')), '1000');
    await tester.pump();
    expect(find.text('1000 g = 1,000 kg'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester
        .ensureVisible(find.byKey(const ValueKey('confirmar_peso_gramas')));
    await tester.tap(find.byKey(const ValueKey('confirmar_peso_gramas')));
    await tester.pumpAndSettle();
    expect(resultado?.gramas, 1000);
    expect(tester.takeException(), isNull);
  });
}
