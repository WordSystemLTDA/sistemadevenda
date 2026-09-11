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
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/pagina_balcao.dart';
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

  @override
  Future<List<MesasModel>> listar(String pesquisa) async =>
      await pendente?.future ??
      [
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
                    ))),
      ];
}

class ComandasTeste extends Fake implements ServicoComandas {
  int quantidade = 200;
  Completer<List<ModeloComandas>>? pendente;

  @override
  Future<List<ModeloComandas>> listar(String pesquisa) async =>
      await pendente?.future ??
      [
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
                    ))),
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
  @override
  Future<ModeloConfigBigchef?> listar() async => null;
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
    i.addInstance<ServicoConfigBigchef>(ConfigBigchefTeste());
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

  test('balcao aceita nova busca durante carregamento e ignora resposta antiga',
      () async {
    modulo.balcao.controlarRespostas = true;
    final antiga = modulo.provedorBalcao.listar(pesquisa: 'Jo');
    final atual = modulo.provedorBalcao.listar(pesquisa: 'Joao');
    expect(modulo.balcao.pendentes, hasLength(2));
    modulo.balcao.pendentes.last.complete([]);
    await atual;
    modulo.balcao.pendentes.first.completeError(Exception('Conexao antiga'));
    await antiga;
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
}
