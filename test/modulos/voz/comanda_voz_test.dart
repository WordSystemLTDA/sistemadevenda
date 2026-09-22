import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/voz/abertura_falada.dart';
import 'package:app/src/modulos/voz/dialogo_comanda_voz.dart';
import 'package:app/src/modulos/voz/lote_pedido_voz.dart';
import 'package:app/src/modulos/voz/pedido_falado.dart';
import 'package:app/src/modulos/voz/servico_pedido_voz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cardapio/carrinhos_por_atendimento_test.dart' show ApiCarrinhoTeste;
import '../cardapio/montagem_pizza_test.dart' as fixture;
import 'dialogo_pedido_voz_test.dart' show GravadorTeste;

Map<String, dynamic> marmita(
        {List<Map<String, dynamic>> ingredientes = const []}) =>
    {
      'tipo': 'produto',
      'produto': 'Almoço Livre',
      'tamanho': '',
      'quantidade': 1,
      'sabores': [],
      'bordas': [],
      'adicionais': [],
      'ingredientes': ingredientes,
      'observacao': '',
      'esclarecimento': '',
    };
Map<String, dynamic> ingrediente(String nome, String acao,
        {String destino = '', bool separado = false}) =>
    {
      'nome': nome,
      'acao': acao,
      'destino': destino,
      'quantidade': 1,
      'separado': separado,
    };
Modelowordprodutos produto() => Modelowordprodutos.fromMap(jsonDecode(
        File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync())
    as Map<String, dynamic>);

class ServicoLoteTeste extends Fake implements ServicoPedidoVoz {
  final List<Map<String, dynamic>?> rascunhos = [];
  final List<Map<String, dynamic>?> contextos = [];
  Completer<LotePedidoVoz>? pendente;
  bool falhar = false;
  bool perguntar = false;
  @override
  bool get suportaLote => true;
  @override
  Future<void> verificar({TipoAberturaVoz? abertura}) async {}
  @override
  Future<LotePedidoVoz> interpretarLote(
      {String? caminho,
      String? texto,
      Map<String, dynamic>? rascunho,
      Map<String, dynamic>? contexto,
      List<ModeloCategoria>? categoriasDisponiveis,
      ModeloConfigBigchef? configuracaoDisponivel}) async {
    rascunhos.add(rascunho);
    contextos.add(contexto == null
        ? null
        : jsonDecode(jsonEncode(contexto)) as Map<String, dynamic>);
    if (perguntar) {
      throw EsclarecimentoPedidoVoz('Qual tamanho?', texto ?? 'Uma pizza');
    }
    if (falhar) throw const FalhaPedidoVoz('Ingrediente indisponível');
    if (pendente != null) return pendente!.future;
    return LotePedidoVoz(
        texto: texto ?? 'Uma marmita',
        pedidos: [PedidoFalado.fromMap(marmita())],
        itens: [produto()..quantidade = 1]);
  }

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UsuarioProvedor usuario;
  late MontadorPedidoVoz montador;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    montador = MontadorPedidoVoz(
        usuario: usuario,
        servicoCategorias: fixture.CategoriasTeste(),
        configuracao: ModeloConfigBigchef.fromMap({
          ...fixture.configBigchef().toMap(),
          'valorembalagemseparada': '3.50'
        }),
        categorias: fixture.CategoriasTeste().categorias,
        catalogo: [produto()]);
  });
  tearDown(() => usuario.dispose());

  test('lote seleciona sabor de produto comum pelo grupo cadastrado', () {
    final dados = marmita()..['sabores'] = ['Frango'];
    final detalhes = produto()
      ..opcoesPacotes!.add(ModeloOpcoesPacotes(
          id: 11,
          titulo: 'Sabor',
          obrigatorio: true,
          tipo: 1,
          dados: [
            ModeloDadosOpcoesPacotes(
                id: 'frango', nome: 'Frango', valor: '2.00')
          ]));
    final montado =
        montador.montar(PedidoFalado.fromMap(dados, lote: true), detalhes);
    expect(montado.valorVenda, '47.00');
    expect(montado.opcoesPacotesListaFinal!.last.dados!.single.nome, 'Frango');
    expect(() => PedidoFalado.fromMap(dados), throwsA(isA<FalhaPedidoVoz>()));
    dados['sabores'] = ['Frango', 'Carne'];
    expect(
        () =>
            montador.montar(PedidoFalado.fromMap(dados, lote: true), detalhes),
        throwsA(isA<FalhaPedidoVoz>()));
  });

  test(
      'duas marmitas diferentes preservam escolhas e cobram embalagem cadastrada',
      () {
    final pedidos = LotePedidoVoz.lerPedidos({
      'itens': [
        marmita(ingredientes: [
          ingrediente('Feijão', 'sem'),
          ingrediente('Arroz', 'pouco')
        ]),
        marmita(ingredientes: [
          ingrediente('Feijão', 'mais', separado: true),
          ingrediente('Carne de Panela', 'trocar', destino: 'Ovo')
        ]),
      ],
      'esclarecimento': ''
    });
    final itens = pedidos.map((p) => montador.montar(p, produto())).toList();
    expect(itens.map((e) => e.valorVenda), ['45.00', '48.50']);
    expect(itens.first.opcoesPacotesListaFinal!.first.dados!.map((d) => d.nome),
        ['POUCO Arroz', 'Carne de Panela', 'SEM Feijão']);
    expect(
        itens.last.opcoesPacotesListaFinal!.first.dados!.map((d) => d.nome), [
      'Arroz',
      'TROCAR Carne de Panela POR 1x Ovo',
      'MAIS Feijão (SEPARADO)'
    ]);
    expect(
        produto().opcoesPacotes!.first.dados!.first.montagemCardapio, isNull);
  });

  test('ação proibida e ingrediente fora do dia bloqueiam a montagem', () {
    for (final alteracao in [
      ingrediente('Arroz', 'sem'),
      ingrediente('Batata', 'mais')
    ]) {
      expect(
          () => montador.montar(
              PedidoFalado.fromMap(marmita(ingredientes: [alteracao])),
              produto()),
          throwsA(isA<FalhaPedidoVoz>()));
    }
  });

  test('troca para ingrediente retirado bloqueia independentemente da ordem',
      () {
    for (final ingredientes in [
      [
        ingrediente('Carne de Panela', 'trocar', destino: 'Feijão'),
        ingrediente('Feijão', 'sem')
      ],
      [
        ingrediente('Feijão', 'sem'),
        ingrediente('Carne de Panela', 'trocar', destino: 'Feijão')
      ],
    ]) {
      expect(
          () => montador.montar(
              PedidoFalado.fromMap(marmita(ingredientes: ingredientes)),
              produto()),
          throwsA(isA<FalhaPedidoVoz>()));
    }
  });

  test('esclarecimento e ingrediente duplicado impedem confirmação parcial',
      () {
    expect(
        () => LotePedidoVoz.lerPedidos({
              'itens': [marmita()],
              'esclarecimento': 'Qual tamanho?'
            }),
        throwsA(isA<FalhaPedidoVoz>()));
    expect(
        () => PedidoFalado.fromMap(marmita(ingredientes: [
              ingrediente('Feijão', 'sem'),
              ingrediente('Feijão', 'mais')
            ])),
        throwsA(isA<FalhaPedidoVoz>()));
  });

  for (final tipo in ['mesa', 'comanda', 'balcao', 'delivery']) {
    test('lote de $tipo preserva carrinho e exige o mesmo atendimento',
        () async {
      final api = ApiCarrinhoTeste();
      final carrinho = ProvedorCarrinho(ServicosItensComanda(api, usuario));
      addTearDown(carrinho.dispose);
      addTearDown(() => api.cliente.close());
      await carrinho.selecionarAtendimento(
          tipo: tipo, idAtendimento: '10', idRecurso: '2');
      final contexto = carrinho.contexto!;
      final item = montador.montar(PedidoFalado.fromMap(marmita()), produto());
      expect(await carrinho.adicionarLoteVoz([item], contexto), isTrue);
      expect(await carrinho.adicionarLoteVoz([item, item], contexto), isTrue);
      expect(carrinho.itensCarrinho.listaComandosPedidos, hasLength(3));
      expect(api.chamadas, isEmpty);
      await carrinho.selecionarAtendimento(
          tipo: tipo, idAtendimento: '11', idRecurso: '3');
      expect(await carrinho.adicionarLoteVoz([item], contexto), isFalse);
      expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    });
  }

  Future<void> abrir(WidgetTester tester, ServicoLoteTeste servico,
      void Function(LotePedidoVoz?) receber,
      {Size tamanho = const Size(320, 568)}) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async => receber(
                        await showDialog<LotePedidoVoz>(
                            context: context,
                            builder: (_) => DialogoComandaVoz(
                                atendimento: 'Delivery #178',
                                servico: servico,
                                gravador: GravadorTeste()))),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  for (final tamanho in [const Size(320, 568), const Size(900, 460)]) {
    testWidgets('rascunho exige confirmação e aceita correção em $tamanho',
        (tester) async {
      final servico = ServicoLoteTeste();
      LotePedidoVoz? confirmado;
      await abrir(tester, servico, (r) => confirmado = r, tamanho: tamanho);
      await tester.enterText(find.byType(TextField), 'Uma marmita');
      await tester.tap(find.text('Interpretar texto'));
      await tester.pumpAndSettle();
      expect(confirmado, isNull);
      expect(find.text('Conferir pedido'), findsOneWidget);
      expect(tester.takeException(), isNull);
      servico.falhar = true;
      await tester.enterText(find.byType(TextField), 'Trocar batata');
      await tester.ensureVisible(find.text('Interpretar texto'));
      await tester.tap(find.text('Interpretar texto'));
      await tester.pumpAndSettle();
      expect(find.text('Ingrediente indisponível'), findsOneWidget);
      expect(servico.rascunhos.last?['itens'], hasLength(1));
      expect(find.text('1. 1x Almoço Livre'), findsOneWidget);
      await tester
          .ensureVisible(find.text('Confirmar e adicionar ao carrinho'));
      await tester.tap(find.text('Confirmar e adicionar ao carrinho'));
      await tester.pumpAndSettle();
      expect(confirmado?.itens, hasLength(1));
    });
  }

  testWidgets('resposta curta preserva o pedido anterior à pergunta',
      (tester) async {
    final servico = ServicoLoteTeste()..perguntar = true;
    await abrir(tester, servico, (_) {});
    await tester.enterText(find.byType(TextField), 'Uma pizza de mussarela');
    await tester.tap(find.text('Interpretar texto'));
    await tester.pumpAndSettle();
    expect(find.text('Qual tamanho?'), findsOneWidget);
    servico.perguntar = false;
    await tester.enterText(find.byType(TextField), 'G');
    await tester.tap(find.text('Interpretar texto'));
    await tester.pumpAndSettle();
    expect(servico.contextos.last?['historico'], ['Uma pizza de mussarela']);
    expect(servico.contextos.last?['pergunta'], 'Qual tamanho?');
    expect(find.text('Conferir pedido'), findsOneWidget);
  });

  testWidgets('fechar durante interpretação descarta resposta atrasada',
      (tester) async {
    final servico = ServicoLoteTeste()..pendente = Completer<LotePedidoVoz>();
    LotePedidoVoz? confirmado;
    await abrir(tester, servico, (r) => confirmado = r);
    await tester.enterText(find.byType(TextField), 'Uma marmita');
    await tester.tap(find.text('Interpretar texto'));
    await tester.pump();
    await tester.tap(find.byTooltip('Fechar pedido por voz'));
    await tester.pumpAndSettle();
    servico.pendente!
        .complete(LotePedidoVoz(texto: '', pedidos: [], itens: [produto()]));
    await tester.pumpAndSettle();
    expect(confirmado, isNull);
    expect(tester.takeException(), isNull);
  });
}
