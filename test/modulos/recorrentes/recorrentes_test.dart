import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/provedores/provedor_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/agenda_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/campos_recorrencia.dart';

ModeloRecorrente pedido(
        {DateTime? data,
        String idDelivery = '',
        String status = 'Previsto',
        bool retirada = false}) =>
    ModeloRecorrente.fromMap({
      'id': '1',
      'cliente': 'Ana Maria · Empresa Centro',
      'idCliente': '10',
      'idDeliveryBase': '80',
      'idDelivery': idDelivery,
      'tipoEntrega': retirada ? '2' : '1',
      'status': status,
      'ativo': 'Sim',
      'total': 37,
      'data': DateFormat('yyyy-MM-dd').format(data ?? DateTime.now()),
      'dias': [1, 2, 3, 4, 5],
      'horarioTipo': 'intervalo',
      'horario': '11:30',
      'horarioFim': '13:00',
      'observacao': 'Entregar na recepção. Sem sal.',
      'itens': [
        {'nome': 'Almoço com arroz, feijão e salada', 'quantidade': 2},
        {'nome': 'Suco de laranja', 'quantidade': 1}
      ],
    });

class Api extends Fake implements ServicosRecorrentes {
  List<ModeloRecorrente> dados = [pedido()];
  Completer<List<ModeloRecorrente>>? espera;
  bool falhar = false;
  int aberturas = 0;
  @override
  Future<List<ModeloRecorrente>> listar(DateTime inicio, DateTime fim,
      {bool cadastros = false}) async {
    if (falhar) throw StateError('Conexão indisponível');
    if (espera != null) return espera!.future;
    return dados;
  }

  @override
  Future<String> abrir(ModeloRecorrente item) async {
    aberturas++;
    return '90';
  }

  @override
  Future<void> editar(ModeloRecorrente item,
      ConfiguracaoRecorrencia configuracao, bool ativo) async {}
}

class _Delivery extends Fake implements ServicoDelivery {}

void main() {
  testWidgets('novo recorrente exige cliente tambem na retirada',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(servico: _Delivery(), recorrente: true)));
    await tester.pumpAndSettle();
    expect(find.text('Novo Recorrente'), findsOneWidget);
    expect(find.text('No local'), findsNothing);
    expect(find.byType(CamposRecorrencia), findsOneWidget);
    await tester.ensureVisible(find.text('Retirada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir cardápio'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione um cliente cadastrado.'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    const fonte = String.fromEnvironment('FONTE_TESTE');
    if (fonte.isNotEmpty) {
      for (final familia in ['Roboto', 'Ahem']) {
        await (FontLoader(familia)
              ..addFont(File(fonte).readAsBytes().then(ByteData.sublistView)))
            .load();
      }
    }
    await (FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
        .load();
  });
  test('opcoes ficam desativadas por padrao e habilitadas somente por Sim', () {
    final configPadrao = ModeloConfigBigchef.fromMap({});
    expect(configPadrao.recorrentesHabilitados, isFalse);
    expect(configPadrao.balcaoRapidoHabilitado, isFalse);
    expect(
        ModeloConfigBigchef.fromMap({'clientecompedidosdecorrentes': 'Sim'})
            .recorrentesHabilitados,
        isTrue);
    expect(
        ModeloConfigBigchef.fromMap({'cliente_com_pedidos_decorrentes': 'Não'})
            .recorrentesHabilitados,
        isFalse);
    expect(
        ModeloConfigBigchef.fromMap({'balcao_rapido': 'Sim'})
            .balcaoRapidoHabilitado,
        isTrue);
  });
  test('valida dias e horario da empresa', () {
    expect(const ConfiguracaoRecorrencia(dias: []).erro, isNotNull);
    expect(
        const ConfiguracaoRecorrencia(
                horarioTipo: 'intervalo', horario: '14:00', horarioFim: '12:00')
            .erro,
        isNotNull);
    expect(
        const ConfiguracaoRecorrencia(horarioTipo: 'fixo', horario: '25:00')
            .erro,
        isNotNull);
    expect(const ConfiguracaoRecorrencia().erro, isNull);
  });
  test('resposta antiga nao substitui a data escolhida', () async {
    final api = Api();
    final p = ProvedorRecorrentes(api);
    api.espera = Completer();
    final espera = api.espera!;
    final primeira = p.listar();
    api.espera = null;
    api.dados = [pedido(idDelivery: '100')];
    await p.listar(dia: DateTime(2026, 9, 25));
    espera.complete([pedido(idDelivery: '50')]);
    await primeira;
    expect(p.itens.single.idDelivery, '100');
    p.dispose();
  });

  for (final caso in [
    (const Size(320, 640), 1.0, false),
    (const Size(360, 640), 1.7, false),
    (const Size(600, 480), 1.0, false),
    (const Size(1366, 768), 1.0, false),
    (const Size(900, 380), 1.0, true)
  ]) {
    testWidgets('agenda e formulario responsivos $caso', (tester) async {
      final api = Api();
      final p = ProvedorRecorrentes(api);
      final chave = GlobalKey();
      tester.view.physicalSize = caso.$1;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(
              colorSchemeSeed: const Color(0xFF6651A7),
              brightness: caso.$3 ? Brightness.dark : Brightness.light),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(caso.$2)),
              child: child!),
          home: RepaintBoundary(
              key: chave,
              child: AgendaRecorrentes(
                  provedor: p,
                  novo: () async {},
                  abrirPedido: (id, item) async {}))));
      await tester.pumpAndSettle();
      expect(find.text('Ana Maria · Empresa Centro'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(tester.takeException(), isNull);
      if (caso.$1.width == 1366 || caso.$1.width == 320) {
        await tester.runAsync(() async {
          final boundary =
              chave.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final imagem = await boundary.toImage();
          final bytes = await imagem.toByteData(format: ui.ImageByteFormat.png);
          final arquivo = File(
              'build/recorrentes/agenda_${caso.$1.width == 320 ? 'mobile' : 'desktop'}.png');
          await arquivo.parent.create(recursive: true);
          await arquivo.writeAsBytes(bytes!.buffer.asUint8List());
          imagem.dispose();
        });
      }
      await Scrollable.ensureVisible(
          tester.element(find.byTooltip('Editar recorrência')),
          alignment: 0.2);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Editar recorrência'));
      await tester.pumpAndSettle();
      expect(find.byType(CamposRecorrencia), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Fechar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
    });
  }
  testWidgets('previsao futura nao gera pedido, falha permite tentar novamente',
      (tester) async {
    final api = Api()
      ..dados = [pedido(data: DateTime.now().add(const Duration(days: 1)))];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();
    final botao = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Agendado'));
    expect(botao.onPressed, isNull);
    expect(api.aberturas, 0);
    api.falhar = true;
    await p.listar();
    await tester.pumpAndSettle();
    expect(find.text('Conexão indisponível'), findsOneWidget);
    expect(find.text('Tentar Novamente'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });
  testWidgets('pesquisa e continuar pedido existente', (tester) async {
    final api = Api()..dados = [pedido(idDelivery: '80', status: 'Pendente')];
    final p = ProvedorRecorrentes(api);
    String? aberto;
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p,
            novo: () async {},
            abrirPedido: (id, _) async {
              aberto = id;
            })));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Continuar Pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar Pedido'));
    await tester.pumpAndSettle();
    expect(aberto, '90');
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado encontrado.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });
}
