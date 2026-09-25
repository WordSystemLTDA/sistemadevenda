import 'dart:async';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_modelo.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/tema/theme_controller.dart';
import 'package:app/src/essencial/widgets/campo_busca.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/pagina_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/pagina_nova_venda_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/card_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comanda.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/inicio/paginas/pagina_inicio.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_mesas.dart';
import 'package:app/src/modulos/mesas/paginas/widgets/card_mesa_ocupada.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../suporte/captura_tela.dart';

class MesasTeste extends Fake implements ServicoMesas {
  int quantidade = 200;
  Completer<List<MesasModel>>? pendente;
  final pendentes = <Completer<List<MesasModel>>>[];
  bool controlarRespostas = false;

  @override
  Future<List<MesasModel>> listar(String pesquisa) async {
    if (controlarRespostas) {
      final pendente = Completer<List<MesasModel>>();
      pendentes.add(pendente);
      return pendente.future;
    }
    return await pendente?.future ?? _dados();
  }

  List<MesasModel> _dados() => [
        MesasModel(
          titulo: 'Livres',
          mesas: List.generate(
            quantidade,
            (i) => MesaModelo(
              id: '$i',
              codigo: '${i + 1}',
              nome: 'Mesa ${i + 1}',
              ativo: 'Sim',
              mesaOcupada: false,
              nomeCliente: null,
              dataAbertura: null,
              horaAbertura: null,
            ),
          ),
        ),
      ];
}

class ComandasTeste extends Fake implements ServicoComandas {
  int quantidade = 200;
  Completer<List<ModeloComandas>>? pendente;
  final pendentes = <Completer<List<ModeloComandas>>>[];
  bool controlarRespostas = false;

  @override
  Future<List<ModeloComandas>> listar(String pesquisa) async {
    if (controlarRespostas) {
      final pendente = Completer<List<ModeloComandas>>();
      pendentes.add(pendente);
      return pendente.future;
    }
    return await pendente?.future ?? _dados();
  }

  List<ModeloComandas> _dados() => [
        ModeloComandas(
          titulo: 'Livres',
          comandas: List.generate(
            quantidade,
            (i) => ModeloComanda(
              id: '$i',
              codigo: '${i + 1}',
              nome: 'Comanda ${i + 1}',
              ativo: 'Sim',
              comandaOcupada: false,
            ),
          ),
        ),
      ];
}

class BalcaoTeste extends Fake implements ServicoBalcao {
  final pesquisas = <String>[];
  final pendentes = <Completer<List<ModeloVendasBalcao>>>[];
  bool controlarRespostas = false;

  @override
  Future<List<ModeloVendasBalcao>> listar(int pagina, int linhasPorPagina,
      String pesquisa, String dataInicio, String dataFim, String hora) async {
    pesquisas.add(pesquisa);
    if (!controlarRespostas) return [];
    final pendente = Completer<List<ModeloVendasBalcao>>();
    pendentes.add(pendente);
    return pendente.future;
  }
}

class ConfigBigchefTeste extends Fake implements ServicoConfigBigchef {
  ModeloConfigBigchef? resposta;

  @override
  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async =>
      resposta;
}

class ConfigTeste extends Fake implements ServicoConfig {
  @override
  Future<ConfigModelo?> listar() async => null;
}

class AutenticacaoTeste extends Fake implements ServicoAutenticacao {}

class ServerTeste extends Server {
  @override
  Future<bool> connect(String ip, String porta) async => true;
}

class ModuloAtendimentoTeste extends Module {
  final mesas = MesasTeste();
  final comandas = ComandasTeste();
  final balcao = BalcaoTeste();
  final configBigchef = ConfigBigchefTeste();
  late final provedorMesas = ProvedorMesas(mesas);
  late final provedorComandas = ProvedorComanda(comandas);
  late final provedorBalcao = ProvedorBalcao(balcao);

  @override
  void binds(Injector i) {
    i.addInstance<ServicoBalcao>(balcao);
    i.addInstance<ProvedorMesas>(provedorMesas);
    i.addInstance<ProvedorComanda>(provedorComandas);
    i.addInstance<ProvedorBalcao>(provedorBalcao);
    i.addInstance<UsuarioProvedor>(UsuarioProvedor()
      ..setUsuario(
          UsuarioModelo(nome: 'Atendente', nomeEmpresa: 'Restaurante')));
    i.addInstance<ServicoConfigBigchef>(configBigchef);
    i.addInstance<ServicoConfig>(ConfigTeste());
    i.addInstance<Server>(ServerTeste());
    i.addInstance<ServicoAutenticacao>(AutenticacaoTeste());
    i.addInstance<ThemeController>(ThemeController());
    i.addInstance<ConfigProvider>(ConfigProvider()
      ..setConfig(ConfigModelo(
        versaoAppAndroid: '1.0.0',
        versaoAppIos: '1.0.0',
        linkAtualizacaoAndroid: '',
        linkAtualizacaoIos: '',
        linkBaixarApk: '',
        nomeApp: '',
        anoApp: '',
        logoApp: '',
      )));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ModuloAtendimentoTeste modulo;

  setUpAll(carregarFontesDeTeste);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
        appName: 'Garcom',
        packageName: 'app',
        version: '1.0.29',
        buildNumber: '30',
        buildSignature: '');
    modulo = ModuloAtendimentoTeste();
    Modular.init(modulo);
  });

  tearDown(Modular.destroy);

  Future<void> abrir(WidgetTester tester, Widget pagina,
      {double largura = 393, bool escuro = false, double escala = 1}) async {
    tester.view.physicalSize = Size(largura, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('captura'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: escuro
            ? ThemeData.dark()
            : ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!),
        home: pagina,
      ),
    ));
    await tester.pumpAndSettle();
  }

  for (final mesa in [true, false]) {
    final nome = mesa ? 'mesas' : 'comandas';
    Widget pagina() => mesa ? const PaginaMesas() : const PaginaComandas();

    for (final largura in [320.0, 393.0, 800.0]) {
      testWidgets('$nome nao mostra botao de voz em $largura', (tester) async {
        await abrir(tester, pagina(), largura: largura);
        final qr = find.byTooltip('Escanear QR Code');
        final voz =
            find.byTooltip('Abrir ${mesa ? 'mesa' : 'comanda'} por voz');
        expect(qr, findsOneWidget);
        expect(voz, findsNothing);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('$nome renderiza so os cartoes visiveis e busca sem requisicao',
        (tester) async {
      await abrir(tester, pagina());
      final cartoes = find.byType(mesa ? CardMesaOcupada : CardComanda);
      expect(cartoes.evaluate().length, lessThan(20));
      expect(cartoes, findsWidgets);
      expect(find.byType(Tab), findsNWidgets(3));
      await tester.enterText(
          find.byType(TextField), mesa ? 'Mesa 199' : 'Comanda 199');
      await tester.pumpAndSettle();
      expect(cartoes, findsOneWidget);
      await tester.tap(find.byTooltip('Limpar busca'));
      await tester.pumpAndSettle();
      expect(cartoes, findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$nome mantem as tres abas quando a lista fica vazia',
        (tester) async {
      modulo.mesas.quantidade = 0;
      modulo.comandas.quantidade = 0;
      await abrir(tester, pagina());
      expect(find.byType(Tab), findsNWidgets(3));
      await tester.tap(find.widgetWithText(Tab, 'Livres'));
      await tester.pumpAndSettle();
      expect(find.text('Nada por aqui'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$nome termina carregamento sem atualizar tela ja fechada',
        (tester) async {
      final mesas = Completer<List<MesasModel>>();
      final comandas = Completer<List<ModeloComandas>>();
      modulo.mesas.pendente = mesas;
      modulo.comandas.pendente = comandas;
      await tester.pumpWidget(MaterialApp(home: pagina()));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      mesas.complete([]);
      comandas.complete([]);
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'balcao reduz debounce, limpa busca e preserva filtro na atualizacao',
      (tester) async {
    await abrir(tester, const PaginaBalcao());
    final busca = find.descendant(
        of: find.byType(CampoBusca), matching: find.byType(TextField));
    await tester.enterText(busca, 'Jo');
    await tester.pump(const Duration(milliseconds: 150));
    await tester.enterText(busca, 'Joao');
    await tester.pump(const Duration(milliseconds: 300));
    expect(modulo.balcao.pesquisas, ['', 'Joao']);
    await modulo.provedorBalcao.listar();
    expect(modulo.balcao.pesquisas.last, 'Joao');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(modulo.balcao.pesquisas.last, '');
    await tester.enterText(busca, 'Pendente');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(modulo.balcao.pesquisas, isNot(contains('Pendente')));
  });

  testWidgets('balcao mostra botao grande e centralizado para nova venda',
      (tester) async {
    await abrir(tester, const PaginaBalcao());

    final botao = find.byKey(const ValueKey('nova-venda-balcao'));
    expect(botao, findsOneWidget);
    expect(find.text('Nova venda'), findsOneWidget);

    final tamanho = tester.getSize(botao);
    final centro = tester.getCenter(botao);
    expect(tamanho.width, 361);
    expect(tamanho.height, greaterThanOrEqualTo(64));
    expect(centro.dx, 196.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('balcao atualiza a lista assim que o fluxo da venda termina',
      (tester) async {
    await abrir(tester, const PaginaBalcao(), largura: 800);
    final consultasAntes = modulo.balcao.pesquisas.length;

    await tester.tap(find.byKey(const ValueKey('nova-venda-balcao')));
    await tester.pumpAndSettle();
    final paginaNova = find.byType(PaginaNovaVendaBalcao);
    expect(paginaNova, findsOneWidget);

    Navigator.of(tester.element(paginaNova)).pop();
    await tester.pumpAndSettle();

    expect(modulo.balcao.pesquisas.length, consultasAntes + 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicio usa painel responsivo com acoes em destaque',
      (tester) async {
    await abrir(tester, const PaginaInicio());

    expect(find.text('Pronto para atender?'), findsOneWidget);
    expect(find.text('Escolha uma área para começar.'), findsOneWidget);
    final menu = find.byTooltip('Abrir menu');
    final statusConexao = find.byKey(const ValueKey('status-conexao-inicio'));
    expect(menu, findsOneWidget);
    expect(statusConexao, findsOneWidget);
    expect(tester.getRect(menu).left, lessThan(20));
    expect(tester.getCenter(menu).dx,
        lessThan(tester.getCenter(statusConexao).dx));
    final marcaEmpresa = find.text('RESTAURANTE');
    expect(marcaEmpresa, findsOneWidget);
    expect(tester.getRect(marcaEmpresa).left,
        greaterThan(tester.getRect(menu).right));
    expect(tester.getRect(marcaEmpresa).left - tester.getRect(menu).right,
        lessThan(65));

    final mesas = find.byKey(const ValueKey('card-home-Mesas'));
    final comandas = find.byKey(const ValueKey('card-home-Comandas'));
    final delivery = find.byKey(const ValueKey('card-home-Delivery'));
    expect(mesas, findsOneWidget);
    expect(comandas, findsOneWidget);
    expect(delivery, findsOneWidget);
    expect(tester.getSize(comandas).width, 361);
    expect(tester.getSize(delivery).width,
        lessThan(tester.getSize(comandas).width));
    expect(tester.getTopLeft(delivery).dy, tester.getTopLeft(mesas).dy);
    expect(tester.getTopLeft(comandas).dy, lessThan(500));

    expect(find.byKey(const ValueKey('atalho-home-Balcão')), findsOneWidget);
    final localizadorImpressoes =
        find.byKey(const ValueKey('card_pendencias_impressao'));
    final impressoes = tester.widget<Material>(localizadorImpressoes);
    expect(
      impressoes.color,
      Theme.of(tester.element(localizadorImpressoes)).colorScheme.surface,
    );
    expect(tester.getSize(localizadorImpressoes).height, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicio mostra acesso a vendas recorrentes quando habilitado',
      (tester) async {
    modulo.configBigchef.resposta = ModeloConfigBigchef.fromMap({
      'clientecompedidosdecorrentes': 'Sim',
    });

    await abrir(tester, const PaginaInicio());

    expect(
        find.byKey(const ValueKey('atalho-home-Recorrentes')), findsOneWidget);
    expect(find.text('Programados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status offline do inicio abre configuracao de conexao',
      (tester) async {
    await abrir(tester, const PaginaInicio());

    await tester.tap(find.byKey(const ValueKey('status-conexao-inicio')));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaConfiguracao), findsOneWidget);
    expect(find.text('Configurar Conexão'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inicio prioriza os atalhos mais usados pelo usuario',
      (tester) async {
    await abrir(tester, const PaginaInicio());

    final balcaoCompacto = find.byKey(const ValueKey('atalho-home-Balcão'));
    expect(balcaoCompacto, findsOneWidget);
    await tester.tap(balcaoCompacto);
    await tester.pumpAndSettle();
    expect(find.byType(PaginaBalcao), findsOneWidget);

    Navigator.of(tester.element(find.byType(PaginaBalcao))).pop();
    await tester.pumpAndSettle();

    final balcaoPriorizado = find.byKey(const ValueKey('card-home-Balcão'));
    expect(balcaoPriorizado, findsOneWidget);
    expect(tester.getSize(balcaoPriorizado).width, 361);
    expect(tester.takeException(), isNull);
  });

  for (final largura in [320.0, 393.0, 800.0]) {
    for (final escuro in [false, true]) {
      for (final tela in ['inicio', 'mesas', 'comandas', 'balcao']) {
        testWidgets('$tela sem cortes em $largura escuro=$escuro',
            (tester) async {
          final pagina = switch (tela) {
            'inicio' => const PaginaInicio(),
            'mesas' => const PaginaMesas(),
            'comandas' => const PaginaComandas(),
            _ => const PaginaBalcao(),
          };
          await abrir(tester, pagina, largura: largura, escuro: escuro);
          expect(tester.takeException(), isNull);
          await capturarTela(tester,
              '${tela}_${largura.toInt()}_${escuro ? 'escuro' : 'claro'}');
        });
      }
    }
  }

  testWidgets('inicio suporta fonte ampliada', (tester) async {
    await abrir(tester, const PaginaInicio(), largura: 320, escala: 1.6);
    expect(find.text('Mesas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final largura in [320.0, 393.0, 800.0]) {
    testWidgets('menu da comanda alinhado a direita em $largura',
        (tester) async {
      await abrir(
          tester,
          Scaffold(
              body: ListView(children: [
            CardComanda(
                itemComanda: ModeloComanda(
              id: '3',
              nome: 'Comanda: 3',
              codigo: '',
              ativo: 'Sim',
              comandaOcupada: true,
              fechamento: false,
              idComandaPedido: '10679',
              nomeCliente: 'Bruno Masson',
              valor: '147.00',
            ))
          ])),
          largura: largura);
      final card = tester.getRect(find.byType(CardComanda));
      final menu = find.byTooltip('Opções da comanda');
      expect(tester.getRect(menu).right, greaterThan(card.right - 25));
      await capturarTela(tester, 'comanda_menu_direita_${largura.toInt()}');
      await tester.tap(menu);
      await tester.pumpAndSettle();
      expect(find.text('Abrir Comanda'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final tela in ['mesas', 'comandas', 'balcao']) {
    testWidgets('$tela suporta celular pequeno com fonte ampliada',
        (tester) async {
      await abrir(
          tester,
          switch (tela) {
            'mesas' => const PaginaMesas(),
            'comandas' => const PaginaComandas(),
            _ => const PaginaBalcao(),
          },
          largura: 320,
          escala: 2);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, '${tela}_320_fonte_ampliada');
    });
  }

  testWidgets('mesas e comandas ocupadas com fonte ampliada', (tester) async {
    await abrir(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          CardComanda(
              itemComanda: ModeloComanda(
            id: '1',
            nome: 'Comanda da varanda',
            codigo: '123456',
            ativo: 'Sim',
            comandaOcupada: true,
            fechamento: true,
            idComandaPedido: '123456',
            nomeCliente: 'Bruno Masson e familia',
            nomeMesa: 'Mesa da varanda',
            valor: '1234.56',
          )),
          CardMesaOcupada(
              item: MesaModelo(
            id: '1',
            nome: 'Mesa da varanda',
            codigo: '123456',
            ativo: 'Sim',
            mesaOcupada: true,
            fechamento: true,
            idComandaPedido: '123456',
            nomeCliente: 'Bruno Masson e familia',
            valor: '1234.56',
            dataAbertura: null,
            horaAbertura: null,
          )),
        ]))),
        largura: 320,
        escala: 2);
    expect(tester.takeException(), isNull);
    await capturarTela(tester, 'ocupadas_320_fonte_ampliada');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('venda no balcao com nome longo e fonte ampliada',
      (tester) async {
    await abrir(
        tester,
        Scaffold(
            body: SingleChildScrollView(
                child: CardVendasBalcao(
          listar: () {},
          item: ModeloVendasBalcao(
            id: '1',
            nomecliente: 'Bruno Masson e familia',
            numeropedido: '123456',
            quantidadeProdutos: '12',
            pagamento: 'Dinheiro',
            subtotal: '1234.56',
            status: 'Concluída',
            nomeusuariocompleto: 'Atendente do balcao',
            nomeusuario: 'Atendente do balcao',
            dataHora: '2026-09-11 11:00:00',
            valorTotalF: '1234.56',
            tamanhoLista: 1,
            idtipodeentrega: '1',
            tipodeentrega: 'Retirada no balcao',
            nomeEmpresa: 'Restaurante',
          ),
        ))),
        largura: 320,
        escala: 2);
    expect(tester.takeException(), isNull);
    await capturarTela(tester, 'venda_balcao_320_fonte_ampliada');
  });

  test('balcao agrupa nova busca durante carregamento e ignora resposta antiga',
      () async {
    modulo.balcao.controlarRespostas = true;
    final antiga = modulo.provedorBalcao.listar(pesquisa: 'Jo');
    final atual = modulo.provedorBalcao.listar(pesquisa: 'Joao');
    expect(modulo.balcao.pendentes, hasLength(1));
    modulo.balcao.pendentes.first.completeError(Exception('Conexao antiga'));
    await Future<void>.delayed(Duration.zero);
    expect(modulo.balcao.pendentes, hasLength(2));
    modulo.balcao.pendentes.last.complete([]);
    await Future.wait([antiga, atual]);
    expect(modulo.provedorBalcao.erro, isNull);
    expect(modulo.provedorBalcao.listando, isFalse);
    expect(modulo.provedorBalcao.pesquisaAtual, 'Joao');
  });

  test('balcao libera carregamento apos falha e aceita tentar novamente',
      () async {
    modulo.balcao.controlarRespostas = true;
    final consulta = modulo.provedorBalcao.listar();
    modulo.balcao.pendentes.last.completeError(Exception('Sem conexao'));
    await consulta;
    expect(modulo.provedorBalcao.erro, isNotNull);
    expect(modulo.provedorBalcao.listando, isFalse);
    final tentativa = modulo.provedorBalcao.listar();
    modulo.balcao.pendentes.last.complete([]);
    await tentativa;
    expect(modulo.provedorBalcao.erro, isNull);
  });

  test('comanda finalizada fica livre imediatamente', () {
    final ocupada = ModeloComanda(
      id: '2',
      nome: 'Comanda: 2',
      codigo: '2',
      ativo: 'Sim',
      comandaOcupada: true,
      idCliente: '10',
      nomeCliente: 'Cliente',
      idComandaPedido: '10851',
      valor: '112.50',
      fechamento: true,
    );
    modulo.provedorComandas.comandas = [
      ModeloComandas(titulo: 'Ocupadas', comandas: [ocupada]),
      ModeloComandas(
        titulo: 'Livres',
        comandas: [
          ModeloComanda(
            id: '1',
            nome: 'Comanda: 1',
            codigo: '1',
            ativo: 'Sim',
            comandaOcupada: false,
          ),
        ],
      ),
    ];

    modulo.provedorComandas.marcarAtendimentoFinalizado('10851');

    expect(modulo.provedorComandas.comandas.first.comandas, isEmpty);
    final livres = modulo.provedorComandas.comandas.last.comandas!;
    expect(livres.map((item) => item.id), ['1', '2']);
    expect(livres.last.comandaOcupada, isFalse);
    expect(livres.last.idComandaPedido, isNull);
    expect(livres.last.nomeCliente, isNull);
    expect(livres.last.valor, isNull);
    expect(livres.last.fechamento, isFalse);
  });

  test('mesa finalizada fica livre imediatamente', () {
    final ocupada = MesaModelo(
      id: '2',
      nome: 'Mesa 2',
      codigo: '2',
      ativo: 'Sim',
      mesaOcupada: true,
      idCliente: '10',
      nomeCliente: 'Cliente',
      dataAbertura: '2026-09-21',
      horaAbertura: '12:00:00',
      idComandaPedido: '10852',
      valor: '80.00',
      fechamento: true,
    );
    modulo.provedorMesas.mesas = [
      MesasModel(titulo: 'Ocupadas', mesas: [ocupada]),
      MesasModel(
        titulo: 'Livres',
        mesas: [
          MesaModelo(
            id: '1',
            nome: 'Mesa 1',
            codigo: '1',
            ativo: 'Sim',
            mesaOcupada: false,
            nomeCliente: null,
            dataAbertura: null,
            horaAbertura: null,
          ),
        ],
      ),
    ];

    modulo.provedorMesas.marcarAtendimentoFinalizado('10852');

    expect(modulo.provedorMesas.mesas.first.mesas, isEmpty);
    final livres = modulo.provedorMesas.mesas.last.mesas!;
    expect(livres.map((item) => item.id), ['1', '2']);
    expect(livres.last.mesaOcupada, isFalse);
    expect(livres.last.idComandaPedido, isNull);
    expect(livres.last.nomeCliente, isNull);
    expect(livres.last.valor, isNull);
    expect(livres.last.fechamento, isFalse);
  });

  test('consulta antiga nao volta a ocupar comanda ja finalizada', () async {
    modulo.provedorComandas.comandas = [
      ModeloComandas(
        titulo: 'Ocupadas',
        comandas: [
          ModeloComanda(
            id: '2',
            nome: 'Comanda: 2',
            codigo: '2',
            ativo: 'Sim',
            comandaOcupada: true,
            idComandaPedido: '10851',
            valor: '96.00',
          ),
        ],
      ),
    ];
    modulo.provedorComandas.marcarAtendimentoFinalizado(
      'id-local-diferente',
      idRecurso: '2',
    );

    modulo.comandas.controlarRespostas = true;
    final consulta = modulo.provedorComandas.listarComandas('');
    modulo.comandas.pendentes.single.complete([
      ModeloComandas(
        titulo: 'Ocupadas',
        comandas: [
          ModeloComanda(
            id: '2',
            nome: 'Comanda: 2',
            codigo: '2',
            ativo: 'Sim',
            comandaOcupada: true,
            idComandaPedido: '10851',
            valor: '96.00',
          ),
        ],
      ),
    ]);
    await consulta;

    final itens = modulo.provedorComandas.comandas
        .expand((grupo) => grupo.comandas ?? const <ModeloComanda>[])
        .toList();
    expect(itens, hasLength(1));
    expect(itens.single.id, '2');
    expect(itens.single.comandaOcupada, isFalse);
    expect(itens.single.idComandaPedido, isNull);
    expect(itens.single.valor, isNull);
  });

  test('consulta antiga nao volta a ocupar mesa ja finalizada', () async {
    modulo.provedorMesas.mesas = [
      MesasModel(
        titulo: 'Ocupadas',
        mesas: [
          MesaModelo(
            id: '2',
            nome: 'Mesa 2',
            codigo: '2',
            ativo: 'Sim',
            mesaOcupada: true,
            nomeCliente: null,
            dataAbertura: null,
            horaAbertura: null,
            idComandaPedido: '10852',
            valor: '75.00',
          ),
        ],
      ),
    ];
    modulo.provedorMesas.marcarAtendimentoFinalizado(
      'id-local-diferente',
      idRecurso: '2',
    );

    modulo.mesas.controlarRespostas = true;
    final consulta = modulo.provedorMesas.listarMesas('');
    modulo.mesas.pendentes.single.complete([
      MesasModel(
        titulo: 'Ocupadas',
        mesas: [
          MesaModelo(
            id: '2',
            nome: 'Mesa 2',
            codigo: '2',
            ativo: 'Sim',
            mesaOcupada: true,
            nomeCliente: null,
            dataAbertura: null,
            horaAbertura: null,
            idComandaPedido: '10852',
            valor: '75.00',
          ),
        ],
      ),
    ]);
    await consulta;

    final itens = modulo.provedorMesas.mesas
        .expand((grupo) => grupo.mesas ?? const <MesaModelo>[])
        .toList();
    expect(itens, hasLength(1));
    expect(itens.single.id, '2');
    expect(itens.single.mesaOcupada, isFalse);
    expect(itens.single.idComandaPedido, isNull);
    expect(itens.single.valor, isNull);
  });

  test('valor lancado aparece imediatamente e nao volta a zero na comanda',
      () async {
    modulo.provedorComandas.comandas = [
      ModeloComandas(
        titulo: 'Ocupadas',
        comandas: [
          ModeloComanda(
            id: '2',
            nome: 'Comanda: 2',
            codigo: '2',
            ativo: 'Sim',
            comandaOcupada: true,
            idComandaPedido: '10853',
            valor: '0.00',
          ),
        ],
      ),
    ];

    modulo.provedorComandas.registrarPedidoLancado(
      '10853',
      idRecurso: '2',
      valorAdicionado: 84,
    );
    var card = modulo.provedorComandas.comandas.single.comandas!.single;
    expect(card.valor, '84.00');
    expect(card.dataultimopedido, isNotNull);

    modulo.comandas.controlarRespostas = true;
    final consulta = modulo.provedorComandas.listarComandas('');
    modulo.comandas.pendentes.single.complete([
      ModeloComandas(
        titulo: 'Ocupadas',
        comandas: [
          ModeloComanda(
            id: '2',
            nome: 'Comanda: 2',
            codigo: '2',
            ativo: 'Sim',
            comandaOcupada: true,
            idComandaPedido: '10853',
            valor: '0.00',
          ),
        ],
      ),
    ]);
    await consulta;

    card = modulo.provedorComandas.comandas.single.comandas!.single;
    expect(card.valor, '84.00');
    expect(card.dataultimopedido, isNotNull);
  });

  test('valor lancado aparece imediatamente e nao volta a zero na mesa',
      () async {
    modulo.provedorMesas.mesas = [
      MesasModel(
        titulo: 'Ocupadas',
        mesas: [
          MesaModelo(
            id: '2',
            nome: 'Mesa 2',
            codigo: '2',
            ativo: 'Sim',
            mesaOcupada: true,
            nomeCliente: null,
            dataAbertura: null,
            horaAbertura: null,
            idComandaPedido: '10854',
            valor: '0.00',
          ),
        ],
      ),
    ];

    modulo.provedorMesas.registrarPedidoLancado(
      '10854',
      idRecurso: '2',
      valorAdicionado: 84,
    );
    var card = modulo.provedorMesas.mesas.single.mesas!.single;
    expect(card.valor, '84.00');
    expect(card.dataultimopedido, isNotNull);

    modulo.mesas.controlarRespostas = true;
    final consulta = modulo.provedorMesas.listarMesas('');
    modulo.mesas.pendentes.single.complete([
      MesasModel(
        titulo: 'Ocupadas',
        mesas: [
          MesaModelo(
            id: '2',
            nome: 'Mesa 2',
            codigo: '2',
            ativo: 'Sim',
            mesaOcupada: true,
            nomeCliente: null,
            dataAbertura: null,
            horaAbertura: null,
            idComandaPedido: '10854',
            valor: '0.00',
          ),
        ],
      ),
    ]);
    await consulta;

    card = modulo.provedorMesas.mesas.single.mesas!.single;
    expect(card.valor, '84.00');
    expect(card.dataultimopedido, isNotNull);
  });

  test('comandas libera carregamento apos timeout e preserva lista antiga',
      () async {
    await modulo.provedorComandas.listarComandas('');
    final listaAntiga = modulo.provedorComandas.comandas;
    expect(listaAntiga.single.comandas, isNotEmpty);

    modulo.comandas.controlarRespostas = true;
    final consulta = modulo.provedorComandas.listarComandas('Bruno');
    modulo.comandas.pendentes.last
        .completeError(TimeoutException('Future not completed'));

    final retorno = await consulta;
    expect(retorno, same(listaAntiga));
    expect(modulo.provedorComandas.comandas, same(listaAntiga));
    expect(modulo.provedorComandas.erro, isNotNull);
    expect(modulo.provedorComandas.listando, isFalse);

    final tentativa = modulo.provedorComandas.listarComandas('');
    modulo.comandas.pendentes.last.complete([]);
    await tentativa;
    expect(modulo.provedorComandas.erro, isNull);
  });

  test('comandas ignora timeout de consulta antiga quando existe busca nova',
      () async {
    modulo.comandas.controlarRespostas = true;
    final antiga = modulo.provedorComandas.listarComandas('Bruno');
    final atual = modulo.provedorComandas.listarComandas('Bruno Masson');
    expect(modulo.comandas.pendentes, hasLength(1));
    modulo.comandas.pendentes.first
        .completeError(TimeoutException('Future not completed'));
    await Future<void>.delayed(Duration.zero);
    expect(modulo.comandas.pendentes, hasLength(2));

    modulo.comandas.pendentes.last.complete([]);
    await Future.wait([antiga, atual]);

    expect(modulo.provedorComandas.erro, isNull);
    expect(modulo.provedorComandas.listando, isFalse);
  });

  test('mesas libera carregamento apos timeout e preserva lista antiga',
      () async {
    await modulo.provedorMesas.listarMesas('');
    final listaAntiga = modulo.provedorMesas.mesas;
    expect(listaAntiga.single.mesas, isNotEmpty);

    modulo.mesas.controlarRespostas = true;
    final consulta = modulo.provedorMesas.listarMesas('Varanda');
    modulo.mesas.pendentes.last
        .completeError(TimeoutException('Future not completed'));

    final retorno = await consulta;
    expect(retorno, same(listaAntiga));
    expect(modulo.provedorMesas.mesas, same(listaAntiga));
    expect(modulo.provedorMesas.erro, isNotNull);
    expect(modulo.provedorMesas.listando, isFalse);

    final tentativa = modulo.provedorMesas.listarMesas('');
    modulo.mesas.pendentes.last.complete([]);
    await tentativa;
    expect(modulo.provedorMesas.erro, isNull);
  });
}
