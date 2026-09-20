import 'package:app/src/modulos/cardapio/paginas/widgets/botao_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('fica largo sem acao principal e compacto ao lado dela',
      (tester) async {
    final expandido = ValueNotifier(true);
    addTearDown(expandido.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ValueListenableBuilder(
            valueListenable: expandido,
            builder: (context, value, _) => BotaoCarrinho(
              quantidade: 0,
              numeroAdicoes: 0,
              expandido: value,
              onPressed: () {},
            ),
          ),
        ),
      ),
    ));

    final botao = find.byType(FloatingActionButton);
    expect(tester.getSize(botao), const Size(144, 56));
    expect(find.text('Carrinho'), findsOneWidget);

    expandido.value = false;
    await tester.pump();

    expect(tester.getSize(botao), const Size(56, 56));
    expect(find.text('Carrinho'), findsNothing);
    expect(find.byIcon(Icons.shopping_cart_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final reduzirAnimacoes in [false, true]) {
    testWidgets(
        'confirma inclusao e respeita reduzir animacoes: $reduzirAnimacoes',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final estado = ValueNotifier((quantidade: 2, adicoes: 0));
      addTearDown(estado.dispose);
      final chamadasHapticas = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform,
              (methodCall) async {
        if (methodCall.method == 'HapticFeedback.vibrate') {
          chamadasHapticas.add(methodCall);
        }
        return null;
      });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null);
      });
      var abriuCarrinho = false;

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(320, 640),
            disableAnimations: reduzirAnimacoes,
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                heightFactor: 1,
                alignment: Alignment.bottomRight,
                child: ValueListenableBuilder(
                  valueListenable: estado,
                  builder: (context, value, _) => BotaoCarrinho(
                    quantidade: value.quantidade,
                    numeroAdicoes: value.adicoes,
                    onPressed: () => abriuCarrinho = true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ));

      final botao = find.byType(FloatingActionButton);
      final tamanhoInicial = tester.getSize(botao);
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      estado.value = (quantidade: 3, adicoes: 1);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
        chamadasHapticas
            .where((chamada) =>
                chamada.arguments == 'HapticFeedbackType.heavyImpact')
            .length,
        1,
      );
      final escala = tester
          .widget<ScaleTransition>(find.ancestor(
            of: botao,
            matching: find.byType(ScaleTransition),
          ))
          .scale
          .value;
      expect(escala, reduzirAnimacoes ? equals(1) : greaterThan(1));
      expect(tester.getSize(botao), tamanhoInicial);
      final mensagem = tester.getRect(find.text('Adicionado ao carrinho'));
      expect(mensagem.left, greaterThanOrEqualTo(0));
      expect(mensagem.right, lessThanOrEqualTo(320));
      expect(mensagem.bottom, lessThan(tester.getRect(botao).top));

      await tester.tap(botao);
      expect(abriuCarrinho, isTrue);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);

      // Recarregar ou remover itens nao deve confirmar uma nova inclusao.
      final totalChamadasHapticas = chamadasHapticas.length;
      estado.value = (quantidade: 1, adicoes: 1);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_rounded), findsNothing);
      expect(chamadasHapticas.length, totalChamadasHapticas);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
