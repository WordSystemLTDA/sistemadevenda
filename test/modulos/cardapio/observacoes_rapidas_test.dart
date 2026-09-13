import 'package:app/src/modulos/cardapio/paginas/widgets/sugestoes_observacao.dart';
import 'package:app/src/modulos/cardapio/provedores/observacoes_rapidas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';

void main() {
  setUpAll(carregarFontesDeTeste);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mantem cadastro, edicao e exclusao ao reabrir o armazenamento',
      () async {
    final repositorio = ObservacoesRapidas();
    expect(await repositorio.listar(), ObservacoesRapidas.padroes);
    await repositorio.salvar('  Cortar em 8  ');
    await repositorio.salvar('Sem sal', anterior: 'Sem cebola');
    await repositorio.excluir('Mal passado');
    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getStringList(ObservacoesRapidas.chave)!;
    expect(salvo, containsAll(['Cortar em 8', 'Sem sal']));
    expect(salvo, isNot(contains('Sem cebola')));
    expect(salvo, isNot(contains('Mal passado')));
    SharedPreferences.setMockInitialValues({ObservacoesRapidas.chave: salvo});
    final reaberto = ObservacoesRapidas();
    expect(await reaberto.listar(), salvo);
    repositorio.dispose();
    reaberto.dispose();
  });

  test('excluir todas nao restaura os padroes ao reabrir', () async {
    final repositorio = ObservacoesRapidas();
    for (final texto in await repositorio.listar()) {
      await repositorio.excluir(texto);
    }
    final reaberto = ObservacoesRapidas();
    expect(await reaberto.listar(), isEmpty);
    repositorio.dispose();
    reaberto.dispose();
  });

  test('valida texto sem perder cadastros e serializa toques rapidos',
      () async {
    final repositorio = ObservacoesRapidas();
    for (final texto in ['', '  ', 'SEM CEBOLA', 'a' * 201]) {
      await expectLater(repositorio.salvar(texto), throwsFormatException);
    }
    await expectLater(repositorio.salvar('Sem sal', anterior: 'Inexistente'),
        throwsFormatException);
    await Future.wait([
      repositorio.salvar('Cortar em 8'),
      repositorio.salvar('Sem gelo'),
      repositorio.excluir('Sem tomate'),
    ]);
    expect(await repositorio.listar(), [
      ...ObservacoesRapidas.padroes.where((s) => s != 'Sem tomate'),
      'Cortar em 8',
      'Sem gelo',
    ]);
    repositorio.dispose();
  });

  for (final (largura, escala) in [(320.0, 1.0), (393.0, 1.0), (800.0, 1.5)]) {
    testWidgets('cadastra, aplica, edita e exclui sugestao em $largura/$escala',
        (tester) async {
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      final controller = TextEditingController(text: 'Bem quente');
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        controller.dispose();
      });
      Widget pagina() => RepaintBoundary(
            key: const ValueKey('captura'),
            child: MaterialApp(
              theme: ThemeData(
                  colorScheme:
                      ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(escala)),
                  child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SugestoesObservacao(controller: controller))),
            ),
          );
      await tester.pumpWidget(pagina());
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Cadastrar observação rápida'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('texto_observacao_rapida')), 'Cortar em 8');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.widgetWithText(ActionChip, 'Cortar em 8'));
      await tester.tap(find.widgetWithText(ActionChip, 'Cortar em 8'));
      expect(controller.text, 'Bem quente, Cortar em 8');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(pagina());
      await tester.pumpAndSettle();
      expect(find.widgetWithText(ActionChip, 'Cortar em 8'), findsOneWidget);
      await tester.tap(find.byTooltip('Gerenciar observações rápidas'));
      await tester.pumpAndSettle();
      await capturarTela(tester, 'observacoes_gerenciar_${largura.toInt()}');
      await tester.scrollUntilVisible(find.byTooltip('Editar Cortar em 8'), 150,
          scrollable: find
              .descendant(
                  of: find.byType(Dialog).last,
                  matching: find.byType(Scrollable))
              .first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar Cortar em 8'));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const Key('texto_observacao_rapida')), 'Cortar em 4');
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Excluir Cortar em 4'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Excluir'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Fechar observações rápidas'));
      await tester.pumpAndSettle();
      expect(find.text('Cortar em 8'), findsNothing);
      expect(find.text('Cortar em 4'), findsNothing);
      expect(controller.text, 'Bem quente, Cortar em 8');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('atalhos respeitam o limite e preservam a observacao digitada',
      (tester) async {
    final controller = TextEditingController(text: 'a' * 195);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body:
                SugestoesObservacao(controller: controller, maxLength: 200))));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Sem cebola'));
    await tester.pumpAndSettle();
    expect(controller.text, 'a' * 195);
    expect(
        find.text('A observação permite até 200 caracteres.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
