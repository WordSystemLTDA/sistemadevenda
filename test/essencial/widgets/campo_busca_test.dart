import 'package:app/src/essencial/widgets/campo_busca.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mostra botao Limpar no lugar do icone de fechar',
      (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    final pesquisas = <String>[];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: CampoBusca(
            controller: controller,
            hintText: 'Nome ou código',
            onChanged: pesquisas.add,
          ),
        ),
      ),
    ));

    expect(find.text('Limpar'), findsNothing);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.enterText(find.byType(TextField), 'coca');
    await tester.pump();

    expect(find.text('Limpar'), findsOneWidget);
    expect(find.byTooltip('Limpar busca'), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsNothing);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pump();

    expect(controller.text, isEmpty);
    expect(pesquisas.last, '');
    expect(find.text('Limpar'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
