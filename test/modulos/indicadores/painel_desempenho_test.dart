import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/indicadores/modelo_indicadores.dart';
import 'package:app/src/modulos/indicadores/pagina_indicadores.dart';
import 'package:app/src/modulos/indicadores/servico_indicadores.dart';
import 'package:app/src/modulos/indicadores/widgets/editor_metas_indicadores.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../suporte/captura_tela.dart';
import 'indicadores_test.dart' show administrador, grupo, relatorio;

class _ServicoDesempenho extends Fake implements ServicoIndicadores {
  @override
  final UsuarioProvedor usuarios = administrador();
  final consultas = <String>[];
  final periodos = <DateTimeRange>[];
  final salvamentos = <(String, MetasIndicadores)>[];
  Completer<ModeloIndicadores>? proximaConsulta;
  String? erroAoSalvar;
  final metas = <String, MetasIndicadores>{
    'empresa': const MetasIndicadores(
      consumoDiarioCentavos: 250000,
      atendimentosDiarios: 35,
      ticketMedioCentavos: 6500,
    ),
    'pessoal': const MetasIndicadores(
      consumoDiarioCentavos: 100000,
      atendimentosDiarios: 15,
      ticketMedioCentavos: 7500,
    ),
  };

  ModeloIndicadores dados(DateTime inicio, DateTime fim, String escopo) {
    final formato = DateFormat('yyyy-MM-dd');
    final atual = formato.format(fim);
    final empresa = escopo == 'empresa';
    final anteriorFim = inicio.subtract(const Duration(days: 1));
    final anteriorInicio =
        anteriorFim.subtract(Duration(days: diasEntreDatas(inicio, fim)));
    return ModeloIndicadores.fromMap({
      ...relatorio(inicio: formato.format(inicio), fim: atual, grupos: [
        grupo(
            dia: atual,
            hora: 12,
            canal: 'Mesa',
            quantidade: empresa ? 12 : 4,
            centavos: empresa ? 85000 : 31000,
            status: 'Finalizada'),
        grupo(
            dia: atual,
            hora: 19,
            quantidade: empresa ? 8 : 2,
            centavos: empresa ? 70000 : 10000),
        grupo(
            dia: atual,
            hora: 20,
            canal: 'Mesa',
            quantidade: 2,
            centavos: 17000,
            status: 'Fechamento'),
        grupo(
            dia: atual,
            hora: 0,
            canal: 'Balcao',
            quantidade: empresa ? 5 : 1,
            centavos: empresa ? 35000 : 4500,
            status: 'Concluída'),
        grupo(
            dia: atual,
            hora: 18,
            quantidade: 1,
            centavos: 0,
            status: 'Cancelada'),
        if (diasEntreDatas(inicio, fim) > 0)
          grupo(
              dia: formato.format(inicio),
              hora: 12,
              quantidade: 3,
              centavos: 15500,
              status: 'Finalizada'),
      ]),
      'escopo': escopo,
      'suporte_metas': true,
      'metas': metas[escopo]!.toMap(),
      'comparacao': {
        'inicio': formato.format(anteriorInicio),
        'fim': formato.format(anteriorFim),
        'grupos': [
          grupo(
              dia: formato.format(anteriorFim),
              quantidade: empresa ? 21 : 7,
              centavos: empresa ? 159000 : 56000)
        ],
      },
      'produtos': [
        {
          'id': 151,
          'nome': 'Almoço Livre',
          'canal': 'Comanda',
          'quantidade': empresa ? 12 : 3,
          'consumo_centavos': empresa ? 54000 : 13500
        },
        {
          'id': 201,
          'nome': 'Filé de frango com acompanhamento e salada da casa',
          'canal': 'Mesa',
          'quantidade': 6,
          'consumo_centavos': 42000
        },
        {
          'id': 12,
          'nome': 'Suco natural',
          'canal': 'Balcao',
          'quantidade': 10,
          'consumo_centavos': 15000
        },
      ],
    });
  }

  @override
  Future<ModeloIndicadores> consultar(DateTime inicio, DateTime fim,
      {CancelToken? cancelToken, String escopo = 'empresa'}) async {
    consultas.add(escopo);
    periodos.add(DateTimeRange(start: inicio, end: fim));
    final pendente = proximaConsulta;
    proximaConsulta = null;
    if (pendente != null) return pendente.future;
    return dados(inicio, fim, escopo);
  }

  @override
  Future<void> salvarMetas(MetasIndicadores novas,
      {required String escopo}) async {
    salvamentos.add((escopo, novas));
    if (erroAoSalvar != null) throw FalhaIndicadores(erroAoSalvar!);
    metas[escopo] = novas;
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  late _ServicoDesempenho servico;
  setUp(() => servico = _ServicoDesempenho());

  Future<void> abrir(WidgetTester tester,
      {double largura = 390,
      double altura = 844,
      double escala = 1,
      bool escuro = false}) async {
    tester.view.physicalSize = Size(largura, altura);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('captura'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: escuro ? Brightness.dark : Brightness.light,
          colorSchemeSeed: const Color(0xFF70579B),
          appBarTheme:
              const AppBarThemeData(actionsPadding: EdgeInsets.only(right: 60)),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: PaginaIndicadores(servico: servico),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> mostrar(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final tela in [
    (390.0, 844.0, 1.0, false),
    (320.0, 700.0, 1.6, false),
    (820.0, 1180.0, 1.0, false),
    (390.0, 844.0, 1.0, true),
  ]) {
    testWidgets('painel enriquecido responsivo $tela', (tester) async {
      await abrir(tester,
          largura: tela.$1, altura: tela.$2, escala: tela.$3, escuro: tela.$4);
      final nome = '${tela.$1}_${tela.$3}_${tela.$4}';
      expect(find.text('DESEMPENHO DO ATENDIMENTO'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'indicadores_novo_inicio_$nome');
      await mostrar(tester, find.text('Metas do atendimento'));
      await capturarTela(tester, 'indicadores_novo_metas_$nome');
      await mostrar(tester, find.text('Movimento por horário'));
      await capturarTela(tester, 'indicadores_novo_horarios_$nome');
      expect(find.byType(SfCartesianChart), findsOneWidget);
      await mostrar(tester, find.text('Por tipo de atendimento'));
      await capturarTela(tester, 'indicadores_novo_canais_$nome');
      expect(find.byType(SfCircularChart), findsOneWidget);
      await mostrar(tester, find.text('Como ler os indicadores'));
      await tester.tap(find.text('Como ler os indicadores'));
      await tester.pumpAndSettle();
      expect(
          find.textContaining(
              'Delivery e recorrentes não compõem estes totais.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'indicadores_novo_rodape_$nome');
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('evolucao diaria alterna consumo e atendimentos no celular',
      (tester) async {
    await abrir(tester, largura: 320, altura: 700, escala: 1.6);
    await mostrar(tester, find.text('Hoje'));
    await tester.tap(find.text('Hoje'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Últimos 7 dias').last);
    await tester.pumpAndSettle();
    await mostrar(tester, find.text('Movimento por dia'));
    await capturarTela(tester, 'indicadores_novo_evolucao_320');
    final atendimentos = find.widgetWithText(ChoiceChip, 'Atendimentos');
    await mostrar(tester, atendimentos);
    await tester.tap(atendimentos);
    await tester.pumpAndSettle();
    expect(tester.widget<ChoiceChip>(atendimentos).selected, isTrue);
    expect(find.textContaining('A média inclui dias sem movimento.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'trocar para meus atendimentos limpa dados da empresa ate resposta',
      (tester) async {
    await abrir(tester);
    final pendente = Completer<ModeloIndicadores>();
    servico.proximaConsulta = pendente;
    await tester.tap(find.text('Meus atendimentos'));
    await tester.pump();
    expect(servico.consultas, ['empresa', 'pessoal']);
    expect(find.text('DESEMPENHO DO ATENDIMENTO'), findsNothing);
    expect(find.text('Metas do atendimento'), findsNothing);
    expect(find.text('Preparando seu desempenho...'), findsOneWidget);
    final periodo = servico.periodos.last;
    pendente.complete(servico.dados(periodo.start, periodo.end, 'pessoal'));
    await tester.pumpAndSettle();
    expect(find.text('MEU DESEMPENHO'), findsOneWidget);
    expect(find.text('Minhas metas'), findsOneWidget);
    expect(find.text('DESEMPENHO DO ATENDIMENTO'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('editor de metas com teclado valida, preserva falha e salva',
      (tester) async {
    await abrir(tester, largura: 320, altura: 700, escala: 1.6);
    await mostrar(tester, find.text('Ajustar metas'));
    await tester.tap(find.text('Ajustar metas'));
    await tester.pumpAndSettle();
    expect(find.byType(EditorMetasIndicadores), findsOneWidget);
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    final consumo = find.byKey(const ValueKey('meta-consumo'));
    final atendimentos = find.byKey(const ValueKey('meta-atendimentos'));
    final ticket = find.byKey(const ValueKey('meta-ticket'));
    final salvar = find.byKey(const ValueKey('salvar-metas'));
    Future<void> mostrarSalvar() async {
      await mostrar(tester, salvar);
      final rolagem = find.descendant(
        of: find.byType(EditorMetasIndicadores),
        matching: find.byType(SingleChildScrollView),
      );
      await tester.drag(rolagem, const Offset(0, -250));
      await tester.pumpAndSettle();
    }

    await mostrar(tester, consumo);
    await tester.enterText(consumo, '15,2,4');
    await mostrarSalvar();
    await capturarTela(tester, 'indicadores_novo_editor_validacao_320');
    await tester.tap(salvar);
    await tester.pumpAndSettle();
    expect(find.text('Informe um valor válido, como 1500,00.'), findsOneWidget);
    expect(servico.salvamentos, isEmpty);
    await mostrar(tester, consumo);
    await tester.enterText(consumo, '1800,50');
    await mostrar(tester, atendimentos);
    await tester.enterText(atendimentos, '25');
    await mostrar(tester, ticket);
    await tester.enterText(ticket, '72,02');
    await capturarTela(tester, 'indicadores_novo_metas_teclado_320');
    servico.erroAoSalvar = 'Servidor indisponível. Tente novamente.';
    await mostrarSalvar();
    await tester.tap(salvar);
    await tester.pumpAndSettle();
    expect(
        find.text('Servidor indisponível. Tente novamente.'), findsOneWidget);
    expect(find.byType(EditorMetasIndicadores), findsOneWidget);
    expect(tester.widget<TextFormField>(consumo).controller!.text, '1800,50');
    servico.erroAoSalvar = null;
    await mostrarSalvar();
    await tester.tap(salvar);
    await tester.pumpAndSettle();
    expect(find.byType(EditorMetasIndicadores), findsNothing);
    expect(servico.salvamentos.last.$1, 'empresa');
    expect(servico.metas['empresa']!.toMap(), {
      'consumo_diario_centavos': 180050,
      'atendimentos_diarios': 25,
      'ticket_medio_centavos': 7202,
    });
    expect(servico.consultas.length, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
