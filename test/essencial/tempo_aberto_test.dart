import 'package:app/src/essencial/widgets/tempo_aberto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('tempo usa abertura real e nao reinicia ao voltar',
      (tester) async {
    var agora = DateTime(2026, 9, 12, 20, 0, 0);
    Widget tela() => MaterialApp(
        home: TempoAberto(
            dataAbertura: '2026-09-12T16:00:00', agora: () => agora));
    await tester.pumpWidget(tela());
    expect(find.text('04:00:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    agora = agora.add(const Duration(minutes: 20));
    await tester.pumpWidget(tela());
    expect(find.text('04:20:00'), findsOneWidget);
    agora = agora.add(const Duration(days: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('28:20:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('data ausente e relogio atrasado nao quebram a tela',
      (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: TempoAberto(dataAbertura: 'invalida')));
    expect(find.text('--:--'), findsOneWidget);
    await tester.pumpWidget(const MaterialApp(
        home: TempoAberto(dataAbertura: '0000-00-00T00:00:00')));
    expect(find.text('--:--'), findsOneWidget);
    await tester.pumpWidget(MaterialApp(
        home: TempoAberto(
            dataAbertura: '2026-09-12T16:00:00',
            agora: () => DateTime(2026, 9, 12, 15))));
    expect(find.text('00:00:00'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
