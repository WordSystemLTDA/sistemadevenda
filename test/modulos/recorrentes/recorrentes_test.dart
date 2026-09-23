import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
        bool retirada = false,
        String cliente = 'Ana Maria · Empresa Centro',
        String horarioTipo = 'intervalo',
        String horario = '11:30',
        String horarioFim = '13:00',
        int tempoEnvio = 20,
        String numeroPedido = '',
        List<Map<String, dynamic>>? itens}) =>
    ModeloRecorrente.fromMap({
      'id': '1',
      'cliente': cliente,
      'idCliente': '10',
      'idDeliveryBase': '80',
      'idDelivery': idDelivery,
      'tipoEntrega': retirada ? '2' : '1',
      'status': status,
      'numeroPedido': numeroPedido,
      'ativo': 'Sim',
      'total': 37,
      'data': DateFormat('yyyy-MM-dd').format(data ?? DateTime.now()),
      'dias': [1, 2, 3, 4, 5],
      'horarioTipo': horarioTipo,
      'horario': horario,
      'horarioFim': horarioFim,
      'tempoParaEnvioDecorrente': tempoEnvio,
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
}

class _Delivery extends Fake implements ServicoDelivery {}

void main() {
  testWidgets('novo recorrente separa geral informacoes e endereco em abas',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(servico: _Delivery(), recorrente: true)));
    await tester.pumpAndSettle();
    expect(find.text('Novo Recorrente'), findsOneWidget);
    expect(find.byKey(const ValueKey('aba-geral-recorrente')), findsOneWidget);
    expect(find.byKey(const ValueKey('aba-informacoes-recorrente')),
        findsOneWidget);
    expect(
        find.byKey(const ValueKey('aba-endereco-recorrente')), findsOneWidget);
    expect(find.text('No local'), findsNothing);
    expect(find.text('Tipo de entrega'), findsOneWidget);
    expect(find.byType(CamposRecorrencia), findsNothing);

    await tester.tap(find.text('Informações'));
    await tester.pumpAndSettle();
    expect(find.byType(CamposRecorrencia), findsOneWidget);
    expect(find.text('Repetir o pedido'), findsOneWidget);
    expect(find.text('Tipo de entrega'), findsNothing);
    expect(find.text('Às 12:00'), findsNothing);

    await tester.ensureVisible(find.text('Qualquer horário'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Qualquer horário'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('A cada pedido'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A cada pedido'));
    await tester.pumpAndSettle();

    await tester
        .ensureVisible(find.byKey(const ValueKey('aba-endereco-recorrente')));
    await tester.tap(find.byKey(const ValueKey('aba-endereco-recorrente')));
    await tester.pumpAndSettle();
    expect(find.byType(CamposRecorrencia), findsOneWidget);
    expect(find.text('Endereço de entrega'), findsOneWidget);
    expect(find.text('Repetir o pedido'), findsNothing);

    await tester
        .ensureVisible(find.byKey(const ValueKey('aba-geral-recorrente')));
    await tester.tap(find.byKey(const ValueKey('aba-geral-recorrente')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retirada'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abrir cardápio'));
    await tester.pumpAndSettle();
    expect(find.text('Selecione um cliente cadastrado.'), findsWidgets);
    expect(find.text('Tipo de entrega'), findsOneWidget);
    expect(find.byType(CamposRecorrencia), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('validacao abre a aba de informacoes quando ela tem pendencias',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(
      servico: _Delivery(),
      recorrente: true,
      clonar: PedidoDelivery.fromMap({
        'idCliente': '7',
        'nomeCliente': 'Cliente recorrente',
        'tipodeentrega': '2',
      }),
    )));
    await tester.pumpAndSettle();

    expect(find.text('Tipo de entrega'), findsOneWidget);
    await tester.tap(find.text('Abrir cardápio'));
    await tester.pumpAndSettle();

    expect(find.byType(CamposRecorrencia), findsOneWidget);
    expect(find.text('Repetir o pedido'), findsOneWidget);
    expect(find.text('Selecione uma opção de horário.'), findsWidgets);
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
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('opcoes ficam desativadas por padrao e habilitadas somente por Sim', () {
    final configPadrao = ModeloConfigBigchef.fromMap({});
    expect(configPadrao.recorrentesHabilitados, isFalse);
    expect(configPadrao.balcaoRapidoHabilitado, isFalse);
    expect(configPadrao.tempoparaenviodecorrente, '20');
    expect(
        ModeloConfigBigchef.fromMap({'tempo_para_envio_decorrente': 35})
            .tempoparaenviodecorrente,
        '35');
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
    const semEscolhas = ConfiguracaoRecorrencia();
    expect(semEscolhas.horarioTipo, isEmpty);
    expect(semEscolhas.pagamentoModo, isEmpty);
    expect(semEscolhas.erro, 'Selecione uma opção de horário.');
    final comHorario = semEscolhas.copyWith(horarioTipo: 'livre');
    expect(comHorario.erro, 'Selecione como o cliente paga.');
    expect(comHorario.copyWith(pagamentoModo: 'diario').erro, isNull);

    const fixo = ConfiguracaoRecorrencia(
        horarioTipo: 'fixo', horario: '12:00', pagamentoModo: 'diario');
    expect(fixo.textoPrimeiroPedido,
        'O primeiro pedido é de hoje. Os próximos seguem os dias escolhidos.');
  });

  test('programa e restaura um endereco para cada dia de entrega', () {
    const configuracao = ConfiguracaoRecorrencia(
      dias: [1, 6, 7],
      horarioTipo: 'livre',
      pagamentoModo: 'diario',
      enderecoModo: 'por_dia',
      enderecosPorDia: {1: '20', 6: '21', 7: '21'},
    );
    final restaurada = ConfiguracaoRecorrencia.fromMap(configuracao.toMap());
    expect(restaurada.erro, isNull);
    expect(restaurada.enderecoModo, 'por_dia');
    expect(restaurada.enderecosPorDia, {1: '20', 6: '21', 7: '21'});
    expect(
      configuracao.copyWith(enderecosPorDia: const {1: '20'}).erro,
      'Escolha o endereço de todos os dias selecionados.',
    );
    expect(configuracao.erroInformacoes, isNull);
    expect(
      configuracao
          .copyWith(enderecosPorDia: const {1: '20'}).erroEnderecoEntrega,
      'Escolha o endereço de todos os dias selecionados.',
    );
  });

  testWidgets('formulario permite escolher o endereco de cada dia',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var configuracao = const ConfiguracaoRecorrencia(
      dias: [1, 6, 7],
      horarioTipo: 'livre',
      pagamentoModo: 'diario',
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: StatefulBuilder(builder: (context, setState) {
            return CamposRecorrencia(
              valor: configuracao,
              somenteEnderecos: true,
              permitirEnderecos: true,
              enderecoPadraoId: '20',
              enderecos: const [
                EnderecoRecorrente(
                    id: '20', endereco: 'Rua Principal', numero: '10'),
                EnderecoRecorrente(
                    id: '21', endereco: 'Rua do Fim de Semana', numero: '50'),
              ],
              onChanged: (valor) => setState(() => configuracao = valor),
            );
          }),
        ),
      ),
    ));
    await tester.ensureVisible(find.text('Escolher por dia'));
    await tester.tap(find.text('Escolher por dia'));
    await tester.pumpAndSettle();
    expect(configuracao.enderecoModo, 'por_dia');
    expect(configuracao.enderecosPorDia.keys, containsAll([1, 6, 7]));
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('formulario informa que o primeiro pedido sempre sera hoje',
      (tester) async {
    final campos = CamposRecorrencia(
      valor: const ConfiguracaoRecorrencia(
          horarioTipo: 'fixo', horario: '12:00', pagamentoModo: 'diario'),
      primeiroPedido: true,
      onChanged: (_) {},
    );
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: campos))));

    expect(find.textContaining('O primeiro pedido é de hoje'), findsOneWidget);
    expect(find.textContaining('primeiro pedido será amanhã'), findsNothing);
    expect(tester.takeException(), isNull);
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
  test('interpreta ingredientes estruturados sem duplicar detalhe legado', () {
    final item = ItemRecorrente.fromMap({
      'nome': 'Marmitex M',
      'quantidade': 1,
      'detalhes': ['Cardápio: POUCO Arroz'],
      'ingredientesCardapio': [
        {'nome': 'Arroz', 'detalhe': 'Pouco'},
        {'nome': 'Carne de Panela', 'detalhe': 'Embalar Separado'},
      ],
    });

    expect(item.detalhes, isEmpty);
    expect(item.ingredientesCardapio, hasLength(2));
    expect(item.ingredientesCardapio.first.nome, 'Arroz');
    expect(item.ingredientesCardapio.first.detalhe, 'Pouco');
    expect(item.ingredientesCardapio.last.nome, 'Carne de Panela');
    expect(item.ingredientesCardapio.last.detalhe, 'Embalar Separado');
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
      if (caso.$1.width < 600) {
        expect(find.byKey(const ValueKey('novo-recorrente')), findsOneWidget);
        expect(find.byType(FloatingActionButton), findsNothing);
        expect(find.text('Deslize para ver os horários'), findsNothing);
        expect(find.byTooltip('Filtrar período'), findsOneWidget);
      } else {
        expect(find.byType(FloatingActionButton), findsOneWidget);
      }
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
  testWidgets('celular usa lista vertical e filtro no padrão do Delivery',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()
      ..dados = [
        pedido(cliente: 'Cliente sem horário', horarioTipo: 'livre'),
        pedido(cliente: 'Cliente com hora marcada', horarioTipo: 'fixo'),
        pedido(
            cliente: 'Cliente no horário da empresa', horarioTipo: 'intervalo')
      ];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('novo-recorrente')), findsOneWidget);
    expect(find.text('Deslize para ver os horários'), findsNothing);
    expect(find.text('Cliente ou produto'), findsOneWidget);
    expect(find.text('Qualquer horário (1)'), findsOneWidget);
    expect(find.text('Horário fixo (1)'), findsOneWidget);
    expect(find.text('Horário da empresa (1)'), findsOneWidget);
    expect(find.text('Cliente sem horário'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('recorrentes-dia-anterior')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('recorrentes-proximo-dia')), findsOneWidget);

    final dataInicial = p.data;
    await tester.tap(find.byKey(const ValueKey('recorrentes-proximo-dia')));
    await tester.pumpAndSettle();
    expect(p.data,
        DateTime(dataInicial.year, dataInicial.month, dataInicial.day + 1));
    expect(api.inicioConsultado, p.data);

    await tester.tap(find.byKey(const ValueKey('recorrentes-dia-anterior')));
    await tester.pumpAndSettle();
    expect(p.data, dataInicial);
    expect(api.inicioConsultado, dataInicial);

    final carrossel =
        find.byKey(const ValueKey('carrossel-horarios-recorrentes'));
    await tester.drag(carrossel, const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(find.text('Cliente com hora marcada'), findsOneWidget);
    await tester.drag(carrossel, const Offset(-360, 0));
    await tester.pumpAndSettle();
    expect(find.text('Cliente no horário da empresa'), findsOneWidget);

    await tester.tap(find.byTooltip('Filtrar período'));
    await tester.pumpAndSettle();
    expect(find.text('Filtrar recorrentes'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('7 dias').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Aplicar'));
    await tester.pumpAndSettle();
    expect(p.visao, 'semana');
    expect(
        api.fimConsultado, DateTime(p.data.year, p.data.month, p.data.day + 6));

    final inicioSemana = p.data;
    await tester.tap(find.byKey(const ValueKey('recorrentes-proximo-dia')));
    await tester.pumpAndSettle();
    expect(p.data,
        DateTime(inicioSemana.year, inicioSemana.month, inicioSemana.day + 1));
    expect(
        api.fimConsultado, DateTime(p.data.year, p.data.month, p.data.day + 6));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });
  testWidgets(
      'ordena os cards, considera o envio ao Delivery e preserva a escolha',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()
      ..dados = [
        pedido(
            idDelivery: '104',
            status: 'Pendente',
            numeroPedido: '4',
            cliente: 'Pedido quatro',
            horarioTipo: 'fixo',
            horario: '10:00'),
        pedido(
            idDelivery: '105',
            status: 'Pendente',
            numeroPedido: '5',
            cliente: 'Pedido cinco',
            horarioTipo: 'fixo',
            horario: '14:00'),
      ];

    Future<ProvedorRecorrentes> abrirAgenda() async {
      final provedor = ProvedorRecorrentes(api);
      await tester.pumpWidget(MaterialApp(
          home: AgendaRecorrentes(
              provedor: provedor,
              novo: () async {},
              abrirPedido: (id, item) async {})));
      await tester.pumpAndSettle();
      return provedor;
    }

    bool apareceAntes(String primeiro, String segundo) =>
        tester.getTopLeft(find.text(primeiro)).dy <
        tester.getTopLeft(find.text(segundo)).dy;

    var provedor = await abrirAgenda();
    expect(find.byKey(const ValueKey('recorrentes-ordenacao')), findsOneWidget);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('recorrentes-linha-data')),
            matching: find.byKey(const ValueKey('recorrentes-ordenacao'))),
        findsOneWidget);
    expect(apareceAntes('#5 Processo Feito', '#4 Processo Feito'), isTrue);

    await tester.tap(find.byKey(const ValueKey('recorrentes-ordenacao')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mais antigos'));
    await tester.pumpAndSettle();
    expect(apareceAntes('#4 Processo Feito', '#5 Processo Feito'), isTrue);

    await tester.tap(find.byKey(const ValueKey('recorrentes-ordenacao')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Envio ao Delivery mais próximo'));
    await tester.pumpAndSettle();
    expect(apareceAntes('#4 Processo Feito', '#5 Processo Feito'), isTrue);
    expect(find.text('Envio ao Delivery: 09:40'), findsOneWidget);
    expect(find.text('Envio ao Delivery: 13:40'), findsOneWidget);
    final preferencias = await SharedPreferences.getInstance();
    expect(preferencias.getString('recorrentes_ordenacao_cards_v1'),
        'envio_proximo');

    await tester.pumpWidget(const SizedBox.shrink());
    provedor.dispose();
    provedor = await abrirAgenda();
    expect(find.byTooltip('Ordenar cartões: Envio ao Delivery mais próximo'),
        findsOneWidget);
    expect(apareceAntes('#4 Processo Feito', '#5 Processo Feito'), isTrue);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    provedor.dispose();
  });
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

  testWidgets('processo feito usa card verde e cabecalho compacto no celular',
      (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = Api()
      ..dados = [
        pedido(
            idDelivery: '80',
            status: 'Pendente',
            numeroPedido: '1',
            cliente: 'Bruno Masson')
      ];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();

    final cabecalho = find.text('#1 Processo Feito');
    expect(cabecalho, findsOneWidget);
    expect(find.text('#1'), findsNothing);
    final card = tester.widget<Card>(
        find.ancestor(of: cabecalho, matching: find.byType(Card)).first);
    expect(card.color, isNotNull);
    expect(card.color!.g, greaterThan(card.color!.r));
    expect(card.color!.g, greaterThan(card.color!.b));
    expect(tester.takeException(), isNull);
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
    await tester.ensureVisible(find.text('Realizar Processo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Realizar Processo'));
    await tester.pumpAndSettle();
    expect(api.aberturas, 1);
    expect(find.text('Pedido enviado para o Delivery.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    p.dispose();
  });

  testWidgets('horario fixo vencido continua aguardando processo manual',
      (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final agora = DateTime(2026, 9, 21, 12, 1);
    final api = Api()
      ..dados = [
        pedido(
          data: DateTime(2026, 9, 21),
          horarioTipo: 'fixo',
          horario: '12:00',
        )
      ];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p,
            novo: () async {},
            abrirPedido: (id, item) async {},
            agora: () => agora)));
    await tester.pumpAndSettle();

    expect(find.text('Entrega'), findsOneWidget);
    expect(find.text('Entrega: 12:00'), findsOneWidget);
    expect(find.text('Envio ao Delivery: 11:40'), findsOneWidget);
    expect(find.text('Aguardando Processo'), findsOneWidget);
    expect(find.textContaining('Envio automático'), findsNothing);
    expect(find.text('Envio Atrasado'), findsNothing);

    await tester.ensureVisible(find.text('Realizar Processo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Realizar Processo'));
    await tester.pumpAndSettle();
    expect(api.aberturas, 1);
    expect(tester.takeException(), isNull);
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
            'detalhes': [
              'Sabores: Calabresa / Frango',
              'Borda: Catupiry',
              'Cardápio: POUCO Arroz / Carne de Panela'
            ]
          }
        ])
      ];
    final p = ProvedorRecorrentes(api);
    await tester.pumpWidget(MaterialApp(
        home: AgendaRecorrentes(
            provedor: p, novo: () async {}, abrirPedido: (id, item) async {})));
    await tester.pumpAndSettle();
    expect(find.text('Pizza especial'), findsNothing);
    expect(find.text('Ingredientes do Cardápio'), findsNothing);
    await tester.tap(find.text('Ver itens'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Pizza especial'), findsOneWidget);
    expect(find.text('• Sabores: Calabresa / Frango'), findsOneWidget);
    expect(find.text('• Borda: Catupiry'), findsOneWidget);
    expect(find.text('Ingredientes do Cardápio'), findsOneWidget);
    expect(find.text('Arroz'), findsOneWidget);
    expect(find.text('Pouco'), findsOneWidget);
    expect(find.text('Carne de Panela'), findsOneWidget);
    expect(find.textContaining('Cardápio:'), findsNothing);
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
