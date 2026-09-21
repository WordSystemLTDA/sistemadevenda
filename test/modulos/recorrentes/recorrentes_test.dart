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
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/servicos/servico_automaticos_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/provedores/provedor_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/agenda_recorrentes.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/campos_recorrencia.dart';

ModeloRecorrente pedido(
        {DateTime? data,
        String idDelivery = '',
        String status = 'Previsto',
        bool retirada = false,
        String cliente = 'Ana Maria · Empresa Centro',
        String horarioTipo = 'intervalo',
        String horario = '11:30',
        String horarioFim = '13:00',
        List<Map<String, dynamic>>? itens}) =>
    ModeloRecorrente.fromMap({
      'id': '1',
      'cliente': cliente,
      'idCliente': '10',
      'idDeliveryBase': '80',
      'idDelivery': idDelivery,
      'tipoEntrega': retirada ? '2' : '1',
      'status': status,
      'ativo': 'Sim',
      'total': 37,
      'data': DateFormat('yyyy-MM-dd').format(data ?? DateTime.now()),
      'dias': [1, 2, 3, 4, 5],
      'horarioTipo': horarioTipo,
      'horario': horario,
      'horarioFim': horarioFim,
      'observacao': 'Entregar na recepção. Sem sal.',
      'itens': itens ??
          [
            {'nome': 'Almoço com arroz, feijão e salada', 'quantidade': 2},
            {'nome': 'Suco de laranja', 'quantidade': 1}
          ],
    });

class Api extends Fake implements ServicosRecorrentes {
  List<ModeloRecorrente> dados = [pedido()];
  Completer<List<ModeloRecorrente>>? espera;
  bool falhar = false;
  int aberturas = 0;
  int exclusoes = 0;
  int processamentosAutomaticos = 0;
  DateTime? inicioConsultado, fimConsultado;
  @override
  Future<List<ModeloRecorrente>> listar(DateTime inicio, DateTime fim,
      {bool cadastros = false}) async {
    inicioConsultado = inicio;
    fimConsultado = fim;
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

  @override
  Future<void> excluir(ModeloRecorrente item) async {
    exclusoes++;
    dados = dados.where((registro) => registro.id != item.id).toList();
  }

  @override
  Future<void> processarAutomaticos() async {
    processamentosAutomaticos++;
  }
}

class _Delivery extends Fake implements ServicoDelivery {}

class _ConfigAutomaticos extends Fake implements ServicoConfigBigchef {
  @override
  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async =>
      ModeloConfigBigchef.fromMap({'clientecompedidosdecorrentes': 'Sim'});
}

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
  test('agenda abre no dia atual e amplia o período sob demanda', () async {
    final api = Api();
    final p = ProvedorRecorrentes(api);
    expect(p.visao, 'dia');
    await p.listar(dia: DateTime(2026, 9, 20));
    expect(api.fimConsultado, api.inicioConsultado);
    await p.listar(modo: 'semana');
    expect(api.fimConsultado, DateTime(2026, 9, 26));
    await p.listar(modo: 'mes');
    expect(api.fimConsultado, DateTime(2026, 10, 19));
    p.dispose();
  });
  test('traduz o status do delivery para o status do processo', () {
    expect(pedido(idDelivery: '80', status: 'Pendente').statusProcesso,
        'Processo Feito');
    expect(pedido(idDelivery: '80', status: 'Cancelado').statusProcesso,
        'Processo Cancelado');
    expect(pedido(status: 'Previsto').statusProcesso, 'Previsto');
  });
  testWidgets('processamento automático acompanha a sessão sem sobrepor minuto',
      (tester) async {
    final api = Api();
    final usuario = UsuarioProvedor();
    final automaticos =
        ServicoAutomaticosRecorrentes(api, usuario, _ConfigAutomaticos())
          ..iniciar();
    usuario.setUsuario(UsuarioModelo(id: '7', empresa: '32'));
    await tester.pump();
    await tester.pump();
    expect(api.processamentosAutomaticos, 1);
    await automaticos.processarAgora();
    expect(api.processamentosAutomaticos, 1);
    await automaticos.processarAgora(forcar: true);
    expect(api.processamentosAutomaticos, 2);
    automaticos.dispose();
    usuario.dispose();
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
      final opcoes = find.byTooltip('Opções do recorrente');
      await Scrollable.ensureVisible(tester.element(opcoes), alignment: 0.2);
      await tester.pumpAndSettle();
      await tester.tap(opcoes);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Editar Recorrência'));
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
    final agendado = find.widgetWithText(FilledButton, 'Agendado');
    final listaVertical = find.byWidgetPredicate((widget) =>
        widget is Scrollable && widget.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(agendado, 300,
        scrollable: listaVertical.first);
    final botao = tester.widget<FilledButton>(agendado);
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
  testWidgets('pesquisa e abre pedido existente sem refazer processo',
      (tester) async {
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
    final ver = find.byTooltip('Ver o Pedido');
    await tester.ensureVisible(ver);
    await tester.pumpAndSettle();
    await tester.tap(ver);
    await tester.pumpAndSettle();
    expect(aberto, '80');
    expect(api.aberturas, 0);
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum resultado encontrado.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });

  testWidgets('processo manual envia ao delivery e exibe confirmação',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()..dados = [pedido(horarioTipo: 'livre')];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Aguardando Processo'), findsOneWidget);
    await tester.tap(find.text('Realizar Processo'));
    await tester.pumpAndSettle();
    expect(api.aberturas, 1);
    expect(find.text('Pedido enviado para o Delivery.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });

  testWidgets('cancelado permite imprimir, visualizar e refazer',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()
      ..dados = [
        pedido(idDelivery: '80', status: 'Cancelado', horarioTipo: 'livre')
      ];
    final p = ProvedorRecorrentes(api);
    var impresso = '';
    var aberto = '';
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p,
            novo: () async {},
            abrirPedido: (id, item) async => aberto = id,
            imprimirPedido: (id, item) async => impresso = id)));
    await tester.pumpAndSettle();
    expect(find.text('Processo Cancelado'), findsOneWidget);
    expect(find.text('Refazer Processo'), findsOneWidget);
    await tester.tap(find.byTooltip('Imprimir Pedido'));
    await tester.pumpAndSettle();
    expect(impresso, '80');
    await tester.tap(find.byTooltip('Ver o Pedido'));
    await tester.pumpAndSettle();
    expect(aberto, '80');
    await tester.tap(find.text('Refazer Processo'));
    await tester.pumpAndSettle();
    expect(api.aberturas, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });

  testWidgets('itens detalhados ficam recolhidos e expandem sob demanda',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()
      ..dados = [
        pedido(horarioTipo: 'livre', itens: [
          {
            'nome': 'Pizza especial',
            'quantidade': 1,
            'detalhes': ['Sabores: Calabresa / Frango', 'Borda: Catupiry']
          }
        ])
      ];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Pizza especial'), findsNothing);
    await tester.tap(find.text('Ver itens'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pizza especial'), findsOneWidget);
    expect(find.text('• Sabores: Calabresa / Frango'), findsOneWidget);
    expect(find.text('• Borda: Catupiry'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });

  testWidgets('menu exclui recorrência somente após confirmação',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()..dados = [pedido(horarioTipo: 'livre')];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Opções do recorrente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir Recorrência'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir recorrência?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(api.exclusoes, 1);
    expect(find.text('Recorrência excluída.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });
}
