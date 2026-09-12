import 'dart:convert';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/widgets/atalhos_pendencias_impressao.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  String mensagem(String id) => jsonEncode({
        'idRequisicao': id,
        'tipoImpressao': '1',
        'tipo': 'Comanda',
        'comanda': 'Comanda: 3',
        'numeroPedido': '10679',
        'nomedopc': 'Cozinha',
        'produtos': [
          {'nome': 'Pizza de queijos especiais', 'quantidade': 1}
        ],
      });

  for (final escala in [1.0, 2.0]) {
    testWidgets(
        'pendencia exige confirmacao antes de reimprimir em escala $escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      await fila.registrar([
        jsonEncode({
          'idRequisicao': 'pizza',
          'tipoImpressao': '1',
          'tipo': 'Comanda',
          'comanda': 'Comanda: 3',
          'numeroPedido': '10679',
          'nomedopc': 'Cozinha',
          'produtos': [
            {'nome': 'Pizza de queijos especiais', 'quantidade': 1}
          ],
        })
      ]);
      await fila.registrarErro('pizza', 'Impressao anterior sem confirmacao');
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reenvios = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: PendenciasImpressao(
            fila: fila,
            reenviar: (_) async {
              reenvios++;
            }),
      ));
      await tester.pumpAndSettle();
      final reenviar = find.widgetWithText(TextButton, 'Reenviar');
      await tester.ensureVisible(reenviar);
      await tester.pumpAndSettle();
      await tester.tap(reenviar);
      await tester.pumpAndSettle();
      expect(reenvios, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(reenvios, 0);
      await tester.tap(reenviar);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reenviar'));
      await tester.pumpAndSettle();
      expect(reenvios, 1);
      expect(fila.itens, hasLength(1));
      await tester.ensureVisible(find.text('Recebido na cozinha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recebido na cozinha'));
      await tester.pumpAndSettle();
      expect(fila.itens, hasLength(1));
      await tester.tap(find.widgetWithText(FilledButton, 'Recebido'));
      await tester.pumpAndSettle();
      expect(fila.itens, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('impressao pendente com produto incompleto nao derruba a tela',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([
      jsonEncode({
        'idRequisicao': 'produto-incompleto',
        'tipoImpressao': '1',
        'tipo': 'Comanda',
        'comanda': 'Comanda: 8',
        'produtos': [
          'linha antiga',
          42,
          {'nome': 'Refrigerante'}
        ],
      })
    ]);

    await tester.pumpWidget(MaterialApp(
      home: PendenciasImpressao(fila: fila, reenviar: (_) async {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Comanda: 8 - #'), findsOneWidget);
    expect(find.text('1x Refrigerante'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('atalhos de impressoes pendentes', () {
    testWidgets('envio automatico nao pode ser apagado apenas no celular',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      await fila.registrar([mensagem('automatica')]);
      await fila.iniciarEnvio('automatica');
      await tester.pumpWidget(MaterialApp(
        home: PendenciasImpressao(fila: fila, reenviar: (_) async {}),
      ));
      expect(find.text('Recebido na cozinha'), findsNothing);
      expect(find.text('Reenviar'), findsOneWidget);
      expect(fila.itens.single.id, 'automatica');
    });

    testWidgets('card mostra o resumo das pendencias', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      var abriu = false;
      await fila.registrar([mensagem('atalho-card')]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CartaoPendenciasImpressao(
              fila: fila,
              onAbrir: (_) => abriu = true,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final card = find.byKey(const ValueKey('card_pendencias_impressao'));
      expect(card, findsOneWidget);
      expect(find.text('Impressões Pendentes'), findsOneWidget);
      expect(find.text('1 impressão aguardando'), findsOneWidget);
      await tester.tap(card);
      expect(abriu, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('botao flutuante fica no lado esquerdo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      var abriu = false;
      await fila.registrar([mensagem('atalho-fab')]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: BotaoFlutuantePendenciasImpressao(
            tag: 'teste',
            fila: fila,
            onAbrir: (_) => abriu = true,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          body: const SizedBox.expand(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final botao =
          find.byKey(const ValueKey('botao_pendencias_impressao_teste'));
      expect(botao, findsOneWidget);
      expect(tester.getRect(botao).left, lessThan(40));
      await tester.tap(botao);
      expect(abriu, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
