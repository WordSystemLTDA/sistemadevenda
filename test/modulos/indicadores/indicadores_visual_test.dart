import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/indicadores/modelo_indicadores.dart';
import 'package:app/src/modulos/indicadores/pagina_indicadores.dart';
import 'package:app/src/modulos/indicadores/servico_indicadores.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import '../../suporte/captura_tela.dart';
import 'indicadores_test.dart' show administrador, grupo, relatorio;

class IndicadoresTeste extends Fake implements ServicoIndicadores {
  @override
  final UsuarioProvedor usuarios = administrador();
  String? erro;
  bool offline = false;
  int chamadas = 0;
  final periodos = <DateTimeRange>[];
  final pendentes = <Completer<ModeloIndicadores>>[];
  bool aguardar = false;

  @override
  Future<ModeloIndicadores> consultar(DateTime inicio, DateTime fim,
      {CancelToken? cancelToken}) async {
    chamadas++;
    periodos.add(DateTimeRange(start: inicio, end: fim));
    if (aguardar) {
      final completer = Completer<ModeloIndicadores>();
      pendentes.add(completer);
      return completer.future;
    }
    if (erro != null) throw FalhaIndicadores(erro!);
    return dados(inicio, fim);
  }

  ModeloIndicadores dados(DateTime inicio, DateTime fim) {
    final data = DateFormat('yyyy-MM-dd');
    return ModeloIndicadores.fromMap(
        relatorio(inicio: data.format(inicio), fim: data.format(fim), grupos: [
          for (var h = 10; h < 24; h++)
            grupo(
                dia: data.format(fim),
                hora: h,
                quantidade: h == 19 ? 8 : h % 4 + 1,
                centavos: 23890),
          grupo(
              dia: data.format(fim),
              canal: 'Balcao',
              quantidade: 10,
              centavos: 65250),
          grupo(
              dia: data.format(fim),
              canal: 'Mesa',
              status: 'Fechamento',
              quantidade: 6,
              centavos: 92000),
        ]),
        offline: offline);
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  late IndicadoresTeste servico;
  setUp(() => servico = IndicadoresTeste());

  Future<void> abrir(WidgetTester tester,
      {double largura = 390,
      double altura = 844,
      double escala = 1,
      bool escuro = false}) async {
    tester.view.physicalSize = Size(largura, altura);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              brightness: escuro ? Brightness.dark : Brightness.light,
              colorSchemeSeed: Colors.deepPurple,
              appBarTheme: const AppBarThemeData(
                  actionsPadding: EdgeInsets.only(right: 60))),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: PaginaIndicadores(servico: servico),
        )));
    if (servico.aguardar) {
      await tester.pump();
    } else {
      await tester.pumpAndSettle();
    }
  }

  for (final tamanho in [
    (390.0, 844.0, 1.0, false),
    (320.0, 700.0, 1.6, false),
    (820.0, 1180.0, 1.0, false),
    (390.0, 844.0, 1.0, true)
  ]) {
    testWidgets('painel responsivo $tamanho', (tester) async {
      await abrir(tester,
          largura: tamanho.$1,
          altura: tamanho.$2,
          escala: tamanho.$3,
          escuro: tamanho.$4);
      expect(find.text('Consumo registrado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(
          tester, 'indicadores_${tamanho.$1}_${tamanho.$3}_${tamanho.$4}');
      await tester.drag(find.byType(ListView).first, const Offset(0, -650));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturarTela(tester,
          'indicadores_grafico_${tamanho.$1}_${tamanho.$3}_${tamanho.$4}');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('erro permite repetir e cache offline fica identificado',
      (tester) async {
    servico.erro = 'Servidor indisponível';
    await abrir(tester);
    expect(find.text('Servidor indisponível'), findsOneWidget);
    servico.erro = null;
    servico.offline = true;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sem conexão'), findsOneWidget);
    expect(servico.chamadas, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('filtrar canal nao faz requisicao extra; trocar periodo atualiza',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Balcão').last);
    await tester.pumpAndSettle();
    expect(find.text('Em andamento'), findsNothing);
    expect(servico.chamadas, 1);
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Últimos 7 dias').last);
    await tester.pumpAndSettle();
    expect(servico.chamadas, 2);
    expect(find.text('Movimento por dia'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('opcao ontem usa o dia operacional anterior', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ontem').last);
    await tester.pumpAndSettle();
    final esperado = dataOperacionalIndicadores(DateTime.now())
        .subtract(const Duration(days: 1));
    expect(servico.periodos.last.start, esperado);
    expect(servico.periodos.last.end, esperado);
    expect(find.text('Ontem'), findsOneWidget);
    expect(servico.chamadas, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('calendario em portugues; cancelar preserva filtro e periodo',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Personalizado').last);
    await tester.pumpAndSettle();
    final calendario = tester.element(find.byType(DateRangePickerDialog));
    expect(
        MaterialLocalizations.of(calendario)
            .formatCompactDate(DateTime(2026, 9, 12)),
        '12/09/2026');
    Navigator.of(calendario).pop();
    await tester.pumpAndSettle();
    expect(find.text('Hoje'), findsOneWidget);
    expect(servico.chamadas, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('periodo personalizado aplica datas e recusa mais de 90 dias',
      (tester) async {
    await abrir(tester);
    final hoje = DateUtils.dateOnly(DateTime.now());
    await tester.tap(find.byTooltip('Selecionar datas'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
        DateTimeRange(
            start: hoje.subtract(const Duration(days: 90)), end: hoje));
    await tester.pumpAndSettle();
    expect(find.text('Selecione até 90 dias.'), findsOneWidget);
    expect(servico.chamadas, 1);
    await tester.tap(find.byTooltip('Selecionar datas'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.byType(DateRangePickerDialog))).pop(
        DateTimeRange(
            start: hoje.subtract(const Duration(days: 89)), end: hoje));
    await tester.pumpAndSettle();
    expect(find.text('Personalizado'), findsOneWidget);
    expect(servico.chamadas, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pausa interrompe atualizacoes e retorno consulta novamente',
      (tester) async {
    await abrir(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(minutes: 2));
    expect(servico.chamadas, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(servico.chamadas, 2);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'resposta antiga nao substitui filtro novo nem causa setState apos sair',
      (tester) async {
    servico.aguardar = true;
    await abrir(tester);
    await tester.tap(find.text('Hoje'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Últimos 7 dias').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(servico.pendentes.length, 2);
    final hoje = DateTime.now();
    servico.pendentes.last
        .complete(servico.dados(hoje.subtract(const Duration(days: 6)), hoje));
    await tester.pumpAndSettle();
    expect(find.text('Movimento por dia'), findsOneWidget);
    servico.pendentes.first.complete(servico.dados(hoje, hoje));
    await tester.pumpAndSettle();
    expect(find.text('Movimento por dia'), findsOneWidget);
    await tester.tap(find.byTooltip('Atualizar indicadores'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    servico.pendentes.last.complete(servico.dados(hoje, hoje));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
