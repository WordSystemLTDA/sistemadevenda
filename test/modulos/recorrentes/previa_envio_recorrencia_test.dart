import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/campos_recorrencia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final caso in [
    ('10:47', 20, '10:27'),
    ('00:10', 20, '23:50 (dia anterior)'),
    ('00:00', 1440, '00:00 (dia anterior)'),
    ('00:10', 2900, '23:50 (3 dias antes)'),
    ('10:47', 0, '10:47'),
    ('10:47', -1, '10:27'),
  ]) {
    test('calcula envio de ${caso.$1} com antecedencia ${caso.$2}', () {
      final valor =
          ConfiguracaoRecorrencia(horarioTipo: 'fixo', horario: caso.$1);
      expect(valor.horarioEnvioTexto(minutosAntes: caso.$2), caso.$3);
    });
  }

  test('faixa da empresa usa o inicio e modos sem horario nao inventam envio',
      () {
    expect(
        const ConfiguracaoRecorrencia(
                horarioTipo: 'intervalo', horario: '11:00', horarioFim: '14:00')
            .horarioEnvioTexto(minutosAntes: 35),
        '10:25');
    for (final valor in const [
      ConfiguracaoRecorrencia(horarioTipo: 'livre'),
      ConfiguracaoRecorrencia(),
      ConfiguracaoRecorrencia(horarioTipo: 'fixo', horario: '25:00'),
      ConfiguracaoRecorrencia(horarioTipo: 'fixo', horario: '11:80'),
    ]) {
      expect(valor.horarioEnvioTexto(minutosAntes: 20), isNull);
    }
  });

  for (final tamanho in [const Size(320, 640), const Size(1000, 800)]) {
    testWidgets('previa acompanha a escolha de horario sem salvar em $tamanho',
        (tester) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var valor = const ConfiguracaoRecorrencia(
          horarioTipo: 'fixo', horario: '10:47', pagamentoModo: 'diario');
      var alteracoes = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                child: StatefulBuilder(
          builder: (context, atualizar) => CamposRecorrencia(
            valor: valor,
            tempoParaEnvioDecorrente: 35,
            onChanged: (novo) => atualizar(() {
              valor = novo;
              alteracoes++;
            }),
          ),
        ))),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Enviar ao Delivery: 10:12'), findsOneWidget);
      expect(find.text('35 min antes do horário de entrega.'), findsOneWidget);
      expect(alteracoes, 0);

      final horario = find.text('Às 10:47');
      await tester.ensureVisible(horario);
      await tester.pumpAndSettle();
      await tester.tap(horario);
      await tester.pumpAndSettle();
      final campos = find.descendant(
          of: find.byType(TimePickerDialog), matching: find.byType(TextField));
      expect(campos, findsNWidgets(2));
      await tester.enterText(campos.at(0), '11');
      await tester.enterText(campos.at(1), '05');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(valor.horario, '11:05');
      expect(find.text('Enviar ao Delivery: 10:30'), findsOneWidget);
      expect(find.text('Enviar ao Delivery: 10:12'), findsNothing);
      expect(alteracoes, 1);

      final livre = find.byKey(const ValueKey('recorrencia-horario-livre'));
      await tester.ensureVisible(livre);
      await tester.pumpAndSettle();
      await tester.tap(livre);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('recorrencia-previa-envio-delivery')),
          findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
