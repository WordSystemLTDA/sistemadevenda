import 'dart:convert';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
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
      await fila.iniciarEnvio('pizza');
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
}
