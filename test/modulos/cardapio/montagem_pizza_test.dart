import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/essencial/modelos/modelo_configuracoes.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/botao_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:app/src/modulos/produto/paginas/pagina_sabor_bordas.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';

ModeloTamanhosPizza tamanho(String id, {int limite = 3}) => ModeloTamanhosPizza(
      id: id,
      nomedotamanho: id,
      quantpedacos: '8',
      saboreslimite: '$limite',
    );

ModeloConfigBigchef configBigchef({String saborlimitedeborda = '2'}) =>
    ModeloConfigBigchef(
      abrircomandadireto: 'Não',
      abrirmesadireto: 'Não',
      agrupamentodeitenscomanda: 'Não',
      agrupamentodeitensmesa: 'Não',
      agrupamentodeitensbalcao: 'Não',
      agrupamentodeitensdelivery: 'Não',
      obrigarjustifcancelarpedido: 'Não',
      mostrarnomeempresapreparo: 'Não',
      mostrarnomeclientepreparo: 'Não',
      tamanhofontepreparoaltura: '1',
      tamanhofontepreparolargura: '1',
      formacobrancaentregadelivery: '',
      valordaentrega: '0',
      agrupamentodeitenscomprovconsumo: 'Não',
      agrupamentodeitenscomproventregador: 'Não',
      valordiferenca: '0',
      saborlimitedeborda: saborlimitedeborda,
      autenticarcomtag: 'Não',
    );

Modelowordprodutos sabor(String id, String categoria, String valorGrande) =>
    Modelowordprodutos(
      id: id,
      nome: id,
      codigo: id,
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: '0',
      categoria: categoria,
      nomeCategoria: categoria,
      habilTipo: 'Pizza',
      ingredientes: [],
      tamanhosPizza: [
        for (final id in ['P', 'G'])
          Modelowordtamanhosproduto(
            id: id,
            nome: id,
            valor: id == 'P' ? '30' : valorGrande,
            foto: '',
            estaSelecionado: false,
            excluir: false,
          ),
      ],
    );

class ConfiguracoesTeste extends Fake implements Modelowordconfiguracoes {
  ConfiguracoesTeste(this.modelovalortamanhopizza, {String? modeloBorda})
      : modelovaloradicionalpizza = modeloBorda ?? modelovalortamanhopizza;

  @override
  final String modelovalortamanhopizza;

  @override
  final String modelovaloradicionalpizza;
}

class CategoriasTeste extends Fake implements ServicosCategoria {
  final categorias = [
    ModeloCategoria(
      id: '0',
      nomeCategoria: 'Todos',
      quantidadeProdutos: '4',
      tamanhosPizza: [],
    ),
    for (final nome in ['Queijos', 'Calabresa', 'Doces'])
      ModeloCategoria(
        id: nome,
        nomeCategoria: nome,
        quantidadeProdutos: '1',
        tamanhosPizza: [tamanho('P', limite: 1), tamanho('G')],
      ),
    ModeloCategoria(
      id: 'Bebidas',
      nomeCategoria: 'Bebidas',
      quantidadeProdutos: '1',
      tamanhosPizza: [],
    ),
  ];

  @override
  Future<List<ModeloCategoria>> listar() async => categorias;
}

class ProdutosTeste extends Fake implements ServicoProduto {
  final consultasPorId = <(String, String)>[];
  final consultasPorNome = <String>[];
  final consultasPorCategoria = <(String, int)>[];
  final produtos = [
    sabor('Mussarela', 'Queijos', '50'),
    sabor('Calabresa especial', 'Calabresa', '70'),
    sabor('Chocolate', 'Doces', '90'),
  ];

  @override
  Future<List<Modelowordprodutos>> listarPorCategoria(
      String categoria, int pagina) async {
    consultasPorCategoria.add((categoria, pagina));
    if (pagina > 1) return [];
    return produtos
        .where((produto) => categoria == '0' || produto.categoria == categoria)
        .toList();
  }

  @override
  Future<List<Modelowordprodutos>> listarPorNome(
      String pesquisa, String categoria, String idcliente,
      {bool codigoExato = false}) async {
    consultasPorNome.add(pesquisa);
    final termo = pesquisa.toLowerCase();
    return produtos
        .where((produto) =>
            (categoria == '0' || produto.categoria == categoria) &&
            (produto.nome.toLowerCase().contains(termo) ||
                produto.codigo.toLowerCase().contains(termo)))
        .map((produto) =>
            Modelowordprodutos.fromMap(produto.toMap())..tamanhosPizza = [])
        .toList();
  }

  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho) async {
    consultasPorId.add((id, tamanho));
    return Modelowordprodutos.fromMap(
        produtos.firstWhere((p) => p.id == id).toMap())
      ..opcoesPacotes = [];
  }
}

class ProdutosComBordasTeste extends ProdutosTeste {
  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho) async {
    consultasPorId.add((id, tamanho));
    return Modelowordprodutos.fromMap(
        produtos.firstWhere((p) => p.id == id).toMap())
      ..opcoesPacotes = [
        ModeloOpcoesPacotes(
          id: 6,
          titulo: 'Selecione as Bordas',
          obrigatorio: false,
          tipo: 4,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: 'Cheddar',
              nome: 'Cheddar',
              valor: '12',
            ),
            ModeloDadosOpcoesPacotes(
              id: 'Catupiry',
              nome: 'Catupiry',
              valor: '12',
            ),
          ],
        ),
      ];
  }
}

class ProdutosComAdicionaisTeste extends ProdutosTeste {
  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho) async {
    consultasPorId.add((id, tamanho));
    return Modelowordprodutos.fromMap(
        produtos.firstWhere((p) => p.id == id).toMap())
      ..opcoesPacotes = [
        ModeloOpcoesPacotes(
          id: 7,
          titulo: 'Selecione os Adicionais',
          obrigatorio: false,
          tipo: 3,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: 'Milho',
              nome: 'Milho',
              valor: '3',
              quantidade: 1,
            ),
            ModeloDadosOpcoesPacotes(
              id: 'Bacon',
              nome: 'Bacon',
              valor: '4',
              quantidade: 1,
            ),
          ],
        ),
      ];
  }
}

class DioClienteTeste extends Fake implements DioCliente {}

class CarrinhoComFalha extends ServicosItensComanda {
  CarrinhoComFalha(super.dio, super.usuarioProvedor);

  @override
  Future<bool> inserir(
          Modelowordprodutos produto,
          tipo,
          idMesa,
          idComanda,
          valor,
          observacaoMesa,
          idProduto,
          String nomeProduto,
          quantidade,
          observacao,
          {required ContextoCarrinho contexto}) async =>
      false;
}

class ConfigBigchefTeste extends Fake implements ServicoConfigBigchef {
  @override
  Future<ModeloConfigBigchef?> listar() async => null;
}

class ModuloTeste extends Module {
  ModuloTeste(this.cardapio, this.usuario, this.produtos);

  final ProvedorCardapio cardapio;
  final UsuarioProvedor usuario;
  final ProdutosTeste produtos;

  @override
  void binds(Injector i) {
    i.addInstance<ProvedorCardapio>(cardapio);
    i.addInstance<ProvedorCarrinho>(
        ProvedorCarrinho(ServicosItensComanda(DioClienteTeste(), usuario)));
    i.addInstance<ProvedorProduto>(ProvedorProduto(cardapio, usuario));
    i.add<ProvedorProdutos>(() => ProvedorProdutos(produtos));
    i.addInstance<ServicoProduto>(produtos);
    i.addInstance<ServicoConfigBigchef>(ConfigBigchefTeste());
    i.addInstance<Server>(Server());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  late ProvedorCardapio cardapio;
  late UsuarioProvedor usuario;
  late ProdutosTeste produtos;
  late CategoriasTeste categorias;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: ConfiguracoesTeste('media')));
    categorias = CategoriasTeste();
    cardapio = ProvedorCardapio(categorias, usuario);
    produtos = ProdutosTeste();
  });

  tearDown(() {
    cardapio.dispose();
    usuario.dispose();
  });

  Future<void> trocarCategoria(WidgetTester tester, String nome) async {
    final aba = find.widgetWithText(Tab, nome);
    await tester.ensureVisible(aba);
    await tester.tap(aba);
    await tester.pumpAndSettle();
  }

  Future<void> tocarTamanho(WidgetTester tester, String nome) async {
    final opcao = find.descendant(
      of: find.byType(ListaTamanhosPizza),
      matching: find.text(nome),
    );
    await tester.ensureVisible(opcao);
    await tester.tap(opcao);
    await tester.pumpAndSettle();
  }

  Future<void> tocarProduto(WidgetTester tester, String nome) async {
    final card = find.byWidgetPredicate(
        (widget) => widget is CardProduto && widget.item.nome == nome);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  Future<bool> adicionar(
      ProvedorCarrinho carrinho, Modelowordprodutos produto) async {
    if (carrinho.contexto == null) {
      await carrinho.selecionarAtendimento(
          tipo: 'comanda', idAtendimento: '10673', idRecurso: '3');
    }
    return carrinho.inserir(produto, 'Comanda', '0', '3', produto.valorVenda,
        '', produto.id, produto.nome, produto.quantidade, '');
  }

  test('contador acompanha inclusoes, edicao, exclusao e carrinho salvo',
      () async {
    final carrinho =
        ProvedorCarrinho(ServicosItensComanda(DioClienteTeste(), usuario));
    addTearDown(carrinho.dispose);
    final bebida = sabor('Agua', 'Bebidas', '10')
      ..tamanhosPizza = []
      ..valorVenda = '10'
      ..quantidade = 1;
    await adicionar(carrinho, bebida);
    await adicionar(carrinho, bebida);
    expect(carrinho.quantidadeDoProduto('Agua'), 2);
    expect(carrinho.numeroAdicoes, 2);

    final editada = Modelowordprodutos.fromMap(bebida.toMap())..quantidade = 3;
    await carrinho.editar(editada, 0);
    expect(carrinho.quantidadeDoProduto('Agua'), 4);
    expect(carrinho.numeroAdicoes, 2);

    final reaberto =
        ProvedorCarrinho(ServicosItensComanda(DioClienteTeste(), usuario));
    addTearDown(reaberto.dispose);
    await reaberto.selecionarAtendimento(
        tipo: 'comanda', idAtendimento: '10673', idRecurso: '3');
    expect(reaberto.quantidadeDoProduto('Agua'), 4);
    expect(reaberto.numeroAdicoes, 0);

    await carrinho.excluirItemCarrinho('Agua', 0);
    await carrinho.listarComandasPedidos();
    expect(carrinho.quantidadeDoProduto('Agua'), 1);
    await carrinho.removerComandasPedidos();
    await carrinho.listarComandasPedidos();
    expect(carrinho.quantidadeDoProduto('Agua'), 0);
  });

  test('inclusoes simultaneas preservam todas as unidades', () async {
    final carrinho =
        ProvedorCarrinho(ServicosItensComanda(DioClienteTeste(), usuario));
    addTearDown(carrinho.dispose);
    final bebida = sabor('Agua', 'Bebidas', '10')
      ..tamanhosPizza = []
      ..valorVenda = '10'
      ..quantidade = 1;
    await Future.wait(List.generate(3, (_) => adicionar(carrinho, bebida)));
    expect(carrinho.quantidadeDoProduto('Agua'), 3);
    expect(carrinho.itensCarrinho.quantidadeTotal, 3);
    expect(carrinho.numeroAdicoes, 3);
  });

  test('falha ao salvar nao marca produto nem confirma inclusao', () async {
    final carrinho =
        ProvedorCarrinho(CarrinhoComFalha(DioClienteTeste(), usuario));
    addTearDown(carrinho.dispose);
    expect(await adicionar(carrinho, sabor('Agua', 'Bebidas', '10')), isFalse);
    expect(carrinho.quantidadeDoProduto('Agua'), 0);
    expect(carrinho.numeroAdicoes, 0);
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
  });

  testWidgets('produto comum fica marcado e atualiza quantidade na pesquisa',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    produtos.produtos.add(sabor('Agua', 'Bebidas', '10')
      ..tamanhosPizza = []
      ..habilTipo = ''
      ..valorVenda = '10');
    await tester.pumpWidget(const MaterialApp(
        home: PaginaCardapio(
            tipo: TipoCardapio.comanda, id: '10673', idComanda: '3')));
    await tester.pumpAndSettle();
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).extendBody, isFalse);
    const chaveContador = ValueKey('quantidade_carrinho_Agua');
    expect(find.byKey(chaveContador), findsNothing);
    await tocarProduto(tester, 'Agua');
    expect(
        find.descendant(
            of: find.byKey(chaveContador), matching: find.text('1')),
        findsOneWidget);
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tocarProduto(tester, 'Agua');
    expect(
        find.descendant(
            of: find.byKey(chaveContador), matching: find.text('2')),
        findsOneWidget);
    final campoBusca = find.byType(TextField).first;
    await tester.showKeyboard(campoBusca);
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(campoBusca, 'Agua');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byKey(chaveContador), matching: find.text('2')),
        findsOneWidget);
    await tocarProduto(tester, 'Agua');
    expect(tester.testTextInput.isVisible, isFalse);
    expect(
        find.descendant(
            of: find.byKey(chaveContador), matching: find.text('3')),
        findsOneWidget);
    final carrinho = Modular.get<ProvedorCarrinho>();
    await carrinho.removerComandasPedidos();
    await carrinho.listarComandasPedidos();
    await tester.pumpAndSettle();
    expect(find.byKey(chaveContador), findsNothing);
    expect(carrinho.numeroAdicoes, 3);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Todos reune tamanhos sem duplicar categorias com o mesmo vinculo',
      () async {
    final res = await cardapio.listarCategorias();
    expect(res.first.tamanhosPizza!.map((e) => e.id), ['P', 'G']);
  });

  test('Todos ignora categorias vazias e preserva tamanhos de grupos distintos',
      () async {
    categorias.categorias.addAll([
      ModeloCategoria(
        id: 'Vazia',
        nomeCategoria: 'Vazia',
        quantidadeProdutos: '0',
        tamanhosPizza: [tamanho('GG')],
      ),
      ModeloCategoria(
        id: 'OutroGrupo',
        nomeCategoria: 'OutroGrupo',
        quantidadeProdutos: '1',
        tamanhosPizza: [tamanho('Familia')],
      ),
    ]);
    final res = await cardapio.listarCategorias();
    expect(res.first.tamanhosPizza!.map((e) => e.id), ['P', 'G', 'Familia']);
  });

  test('Todos nao mostra tamanhos quando nao ha produtos de pizza', () async {
    for (final categoria in categorias.categorias.skip(1)) {
      if (categoria.tamanhosPizza!.isNotEmpty) {
        categoria.quantidadeProdutos = '0';
      }
    }
    final res = await cardapio.listarCategorias();
    expect(res.first.tamanhosPizza, isEmpty);
  });

  test('pesquisa completa pizza sem cache buscando a categoria real', () async {
    final provedor = ProvedorProdutos(produtos);

    await provedor.listarProdutosPorNome('Calabresa', '0', '0');

    expect(provedor.produtos, hasLength(1));
    expect(provedor.produtos.single.id, 'Calabresa especial');
    expect(
      provedor.produtos.single.tamanhosPizza!.map((tamanho) => tamanho.valor),
      ['30', '70'],
    );
    expect(produtos.consultasPorCategoria, [('Calabresa', 1)]);
  });

  for (final largura in [320.0, 393.0, 800.0]) {
    testWidgets('monta pizza em Todos e avanca ate o carrinho em $largura',
        (tester) async {
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Modular.init(ModuloTeste(cardapio, usuario, produtos));
      addTearDown(Modular.destroy);
      produtos.produtos.add(sabor('Agua', 'Bebidas', '10')
        ..tamanhosPizza = []
        ..habilTipo = ''
        ..valorVenda = '10');

      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
          home: const PaginaCardapio(
              tipo: TipoCardapio.comanda, id: '10673', idComanda: '3'),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(ListaTamanhosPizza), findsOneWidget);
      expect(cardapio.categorias.first.tamanhosPizza, hasLength(2));
      await tocarTamanho(tester, 'G');
      await tocarProduto(tester, 'Mussarela');
      await trocarCategoria(tester, 'Calabresa');
      await tocarProduto(tester, 'Calabresa especial');
      await trocarCategoria(tester, 'Todos');
      expect(cardapio.tamanhosPizza?.id, 'G');
      expect(cardapio.saboresPizzaSelecionados, hasLength(2));
      expect(
          tester.widget<BotaoAcaoPedido>(find.byType(BotaoAcaoPedido)).rotulo,
          'Avançar (2)');
      await tocarProduto(tester, 'Chocolate');
      final carrinho = Modular.get<ProvedorCarrinho>();
      expect(carrinho.numeroAdicoes, 0);
      expect(
          find.descendant(
              of: find.byType(BotaoCarrinho),
              matching: find.byIcon(Icons.check_rounded)),
          findsNothing);
      expect(find.byKey(const ValueKey('quantidade_carrinho_Mussarela')),
          findsNothing);
      await tocarProduto(tester, 'Agua');
      expect(cardapio.saboresPizzaSelecionados, hasLength(3));
      expect(cardapio.calcularPrecoPizza(), 70);
      expect(carrinho.itensCarrinho.listaComandosPedidos.single.nome, 'Agua');
      expect(carrinho.numeroAdicoes, 1);
      expect(
          find.descendant(
              of: find.byType(BotaoCarrinho),
              matching: find.byIcon(Icons.check_rounded)),
          findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.runAsync(() => precacheImage(
          const AssetImage(Assets.produtoAsset),
          tester.element(find.byType(CardProduto).first)));
      await tester.pump();
      await capturarTela(tester, 'cardapio_${largura.toInt()}');
      final botao = find.byType(BotaoAcaoPedido);
      final rectAvancar = tester.getRect(botao);
      final rectCarrinho = tester.getRect(find.byType(FloatingActionButton));
      expect(rectAvancar.overlaps(rectCarrinho), isFalse);
      expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Avançar (3)');
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(find.byType(PaginaSaborBordas), findsOneWidget);
      expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Avançar');
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<PaginaProduto>(find.byType(PaginaProduto))
              .montagemPizza,
          isTrue);
      expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Adicionar ao');
      await tester.tap(botao);
      await tester.pumpAndSettle();
      final pizza = carrinho.itensCarrinho.listaComandosPedidos
          .firstWhere((p) => p.id == 'Mussarela');
      expect(pizza.valorVenda, '70.00');
      expect(pizza.opcoesPacotesListaFinal!.firstWhere((o) => o.id == 10).dados,
          hasLength(3));
      expect(carrinho.numeroAdicoes, 2);
      expect(carrinho.quantidadeDoProduto('Mussarela'), 0);
      expect(find.byType(PaginaCardapio), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(
          tester.widget<BotaoCarrinho>(find.byType(BotaoCarrinho)).quantidade,
          2);
      await capturarTela(tester, 'pizza_adicionada_${largura.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('produto comum com opcoes nao herda a pizza em montagem',
      (tester) async {
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    await Modular.get<ProvedorCarrinho>().selecionarAtendimento(
        tipo: 'comanda', idAtendimento: '10673', idRecurso: '3');
    cardapio.idComanda = '3';
    cardapio.id = '10673';
    final bebida = sabor('Bebida com opcoes', 'Bebidas', '10')
      ..tamanhosPizza = []
      ..habilTipo = 'Pacote'
      ..valorVenda = '10';
    produtos.produtos.add(bebida);
    cardapio.tamanhosPizza = tamanho('G');
    cardapio.selecionarSaborPizza(produtos.produtos.first);
    await tester.pumpWidget(MaterialApp(home: PaginaProduto(produto: bebida)));
    await tester.pumpAndSettle();
    expect(produtos.consultasPorId.single, ('Bebida com opcoes', '0'));
    await tester.tap(find.byType(BotaoAcaoPedido));
    await tester.pumpAndSettle();
    final item = Modular.get<ProvedorCarrinho>()
        .itensCarrinho
        .listaComandosPedidos
        .single;
    expect(item.opcoesPacotesListaFinal!.where((o) => o.id == 9 || o.id == 10),
        isEmpty);
    expect(item.valorVenda, '10.00');
    expect(cardapio.saboresPizzaSelecionados, hasLength(1));
    expect(cardapio.tamanhosPizza?.id, 'G');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('botao adicionar mostra quantidade de adicionais selecionados',
      (tester) async {
    produtos = ProdutosComAdicionaisTeste();
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    final bebida = sabor('Bebida com adicionais', 'Bebidas', '10')
      ..tamanhosPizza = []
      ..habilTipo = 'Pacote'
      ..valorVenda = '10';
    produtos.produtos.add(bebida);

    await tester.pumpWidget(MaterialApp(home: PaginaProduto(produto: bebida)));
    await tester.pumpAndSettle();

    final botao = find.byType(BotaoAcaoPedido);
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Adicionar ao');

    await tester.tap(find.text('Milho'));
    await tester.pumpAndSettle();
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Adicionar ao (1)');

    await tester.tap(find.text('Bacon'));
    await tester.pumpAndSettle();
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Adicionar ao (2)');

    final primeiroAdicional = find.byType(CardOpcoesPacotes).first;
    await tester.tap(find.descendant(
      of: primeiroAdicional,
      matching: find.byIcon(Icons.add_circle_outline),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Adicionar ao (3)');
  });

  testWidgets('pesquisa reaproveita tamanhos da listagem ja carregada',
      (tester) async {
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);

    await tester.pumpWidget(const MaterialApp(
        home: PaginaCardapio(
            tipo: TipoCardapio.comanda, id: '10673', idComanda: '3')));
    await tester.pumpAndSettle();

    await tocarTamanho(tester, 'G');
    await tester.enterText(find.byType(TextField), 'Muss');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(produtos.consultasPorNome, ['Muss']);
    expect(find.textContaining(r'50,00'), findsOneWidget);
    await tocarProduto(tester, 'Mussarela');
    expect(cardapio.saboresPizzaSelecionados.map((produto) => produto.id),
        ['Mussarela']);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('check do tamanho selecionado fica dentro da lista visivel',
      (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);

    await tester.pumpWidget(const MaterialApp(
        home: PaginaCardapio(
            tipo: TipoCardapio.comanda, id: '10673', idComanda: '3')));
    await tester.pumpAndSettle();
    await tocarTamanho(tester, 'G');

    final listaRect = tester.getRect(find.byType(ListaTamanhosPizza));
    final checkRect = tester.getRect(find.descendant(
      of: find.byType(ListaTamanhosPizza),
      matching: find.byIcon(Icons.check_rounded),
    ));

    expect(checkRect.top, greaterThanOrEqualTo(listaRect.top));
    expect(checkRect.right, lessThanOrEqualTo(listaRect.right));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('nao seleciona borda antes da quantidade de sabores', () {
    cardapio.configBigchef = configBigchef(saborlimitedeborda: '2');
    final provedorProduto = ProvedorProduto(cardapio, usuario);
    final cheddar = ModeloDadosOpcoesPacotes(
      id: 'Cheddar',
      nome: 'Cheddar',
      valor: '12',
    );
    final opcaoDisponivel = ModeloOpcoesPacotes(
      id: 6,
      titulo: 'Selecione as Bordas',
      obrigatorio: false,
      tipo: 4,
      dados: [cheddar],
    );
    final opcaoFinal = ModeloOpcoesPacotes(
      id: 6,
      titulo: 'Selecione as Bordas',
      obrigatorio: false,
      tipo: 4,
      dados: [],
    );
    provedorProduto.opcoesPacotesListaFinal = [opcaoFinal];

    provedorProduto.selecionarItem(cheddar, opcaoDisponivel, false, '0');

    expect(provedorProduto.retornarDadosPorID([6], false, '0'), isEmpty);
    expect(cheddar.estaSelecionado, isNull);

    cardapio.limiteSaborBordaSelecionado = 1;
    provedorProduto.selecionarItem(cheddar, opcaoDisponivel, false, '0');
    expect(provedorProduto.retornarDadosPorID([6], false, '0'), [cheddar]);
  });

  testWidgets('card de borda avisa quando quantidade nao foi selecionada',
      (tester) async {
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    cardapio.configBigchef = configBigchef(saborlimitedeborda: '2');
    final provedorProduto = Modular.get<ProvedorProduto>();
    final cheddar = ModeloDadosOpcoesPacotes(
      id: 'Cheddar',
      nome: 'Cheddar',
      valor: '12',
    );
    final opcaoDisponivel = ModeloOpcoesPacotes(
      id: 6,
      titulo: 'Selecione as Bordas',
      obrigatorio: false,
      tipo: 4,
      dados: [cheddar],
    );
    provedorProduto.opcoesPacotesListaFinal = [
      ModeloOpcoesPacotes(
        id: 6,
        titulo: 'Selecione as Bordas',
        obrigatorio: false,
        tipo: 4,
        dados: [],
      )
    ];

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardOpcoesPacotes(
          opcoesPacote: opcaoDisponivel,
          item: cheddar,
          kit: false,
          idProduto: '0',
        ),
      ),
    ));

    await tester.tap(find.text('Cheddar'));
    await tester.pump();

    expect(find.text('Selecione a quantidade de sabores da borda primeiro.'),
        findsOneWidget);
    expect(provedorProduto.retornarDadosPorID([6], false, '0'), isEmpty);

    cardapio.limiteSaborBordaSelecionado = 1;
    await tester.tap(find.text('Cheddar'));
    await tester.pump();

    expect(provedorProduto.retornarDadosPorID([6], false, '0'), [cheddar]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('botao de avancar mostra quantidade de bordas selecionadas',
      (tester) async {
    produtos = ProdutosComBordasTeste();
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    cardapio.configBigchef = configBigchef(saborlimitedeborda: '2');
    cardapio.tamanhosPizza = tamanho('G');

    await tester.pumpWidget(MaterialApp(
      home: PaginaSaborBordas(
        produto: produtos.produtos.first,
        valorVenda: 50,
      ),
    ));
    await tester.pumpAndSettle();

    final botao = find.byType(BotaoAcaoPedido);
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Avançar');

    await tester.tap(find.text('até 2 sabores'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cheddar'));
    await tester.pumpAndSettle();
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Avançar (1)');

    await tester.tap(find.text('Catupiry'));
    await tester.pumpAndSettle();
    expect(tester.widget<BotaoAcaoPedido>(botao).rotulo, 'Avançar (2)');
  });

  testWidgets('controle de aplicacao da borda aparece com padrao inteira',
      (tester) async {
    produtos = ProdutosComBordasTeste();
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    cardapio.configBigchef = configBigchef(saborlimitedeborda: '2');
    cardapio.tamanhosPizza = tamanho('G');

    await tester.pumpWidget(MaterialApp(
      home: PaginaSaborBordas(
        produto: produtos.produtos.first,
        valorVenda: 50,
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Aplicação da borda'), findsOneWidget);
    expect(find.textContaining('Pizza inteira selecionada'), findsOneWidget);
    expect(find.textContaining(RegExp(r'Cobrança:.*0,00')), findsOneWidget);
    expect(
      tester
          .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
          .selected,
      {false},
    );
    final card =
        tester.getRect(find.byKey(const ValueKey('controle_meia_borda_card')));
    final seletor = tester
        .getRect(find.byKey(const ValueKey('controle_meia_borda_seletor')));
    expect(seletor.width, closeTo(card.width - 20, 0.1));
  });

  testWidgets('meia borda cobra somente metade no fluxo da pizza',
      (tester) async {
    produtos = ProdutosComBordasTeste();
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    addTearDown(Modular.destroy);
    cardapio.configBigchef = configBigchef(saborlimitedeborda: '2');
    cardapio.tamanhosPizza = tamanho('G');

    await tester.pumpWidget(MaterialApp(
      home: PaginaSaborBordas(
        produto: produtos.produtos.first,
        valorVenda: 50,
      ),
    ));
    await tester.pumpAndSettle();

    final botao = find.byType(BotaoAcaoPedido);
    await tester.tap(find.text('1 sabor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cheddar'));
    await tester.pumpAndSettle();
    expect(tester.widget<BotaoAcaoPedido>(botao).total, contains('62,00'));

    await tester.tap(find.text('Meia'));
    await tester.pumpAndSettle();

    expect(tester.widget<BotaoAcaoPedido>(botao).total, contains('56,00'));
    expect(find.text('Meia pizza'), findsOneWidget);
    expect(find.textContaining('Cobrança:'), findsWidgets);
    expect(find.textContaining('6,00'), findsWidgets);
    expect(
        Modular.get<ProvedorProduto>()
            .retornarDadosPorID([6], false, '0')
            .single
            .somenteMetadeBorda,
        isTrue);
  });

  for (final largura in [393.0, 800.0]) {
    testWidgets('mantem pizza ao trocar categorias em tela de $largura',
        (tester) async {
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Modular.init(ModuloTeste(cardapio, usuario, produtos));
      addTearDown(Modular.destroy);

      await tester.pumpWidget(const MaterialApp(
        home: PaginaCardapio(
            tipo: TipoCardapio.comanda, id: '10673', idComanda: '3'),
      ));
      await tester.pumpAndSettle();

      await trocarCategoria(tester, 'Queijos');
      await tocarTamanho(tester, 'G');
      await tester.tap(find.byType(CardProduto));
      await tester.pumpAndSettle();

      await trocarCategoria(tester, 'Calabresa');
      expect(cardapio.tamanhosPizza?.id, 'G');
      expect(cardapio.saboresPizzaSelecionados.map((e) => e.id), ['Mussarela']);
      expect(find.textContaining('70,00'), findsOneWidget);
      await tester.tap(find.byType(CardProduto));
      await tester.pumpAndSettle();

      await trocarCategoria(tester, 'Doces');
      await tester.tap(find.byType(CardProduto));
      await tester.pumpAndSettle();
      expect(cardapio.saboresPizzaSelecionados, hasLength(3));
      expect(cardapio.calcularPrecoPizza(), 70);
      expect(find.textContaining(r'70,00'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await trocarCategoria(tester, 'Queijos');
      expect(
          find.byWidgetPredicate((widget) =>
              widget is Icon && widget.semanticLabel == 'Selecionado'),
          findsOneWidget);
      await tester.tap(find.byType(CardProduto));
      await tester.pumpAndSettle();
      expect(cardapio.saboresPizzaSelecionados, hasLength(2));
      expect(cardapio.calcularPrecoPizza(), 80);

      await tocarTamanho(tester, 'G');
      expect(cardapio.tamanhosPizza, isNull);
      expect(cardapio.saboresPizzaSelecionados, isEmpty);

      await tocarTamanho(tester, 'G');
      await tester.tap(find.byType(CardProduto));
      await tester.pumpAndSettle();
      await trocarCategoria(tester, 'Bebidas');
      expect(cardapio.tamanhosPizza, isNull);
      expect(cardapio.saboresPizzaSelecionados, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  test('limita sabores entre categorias e permite desmarcar no limite', () {
    cardapio.tamanhosPizza = tamanho('G', limite: 2);
    for (final produto in produtos.produtos) {
      cardapio.selecionarSaborPizza(produto);
    }
    expect(cardapio.saboresPizzaSelecionados, hasLength(2));
    cardapio.selecionarSaborPizza(produtos.produtos.first);
    cardapio.selecionarSaborPizza(produtos.produtos.last);
    expect(cardapio.saboresPizzaSelecionados.map((e) => e.id),
        ['Calabresa especial', 'Chocolate']);
  });

  for (final regra in ['media', 'maior']) {
    test('recalcula $regra pelo tamanho sem depender dos cards visiveis', () {
      usuario.setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: ConfiguracoesTeste(regra)));
      cardapio.tamanhosPizza = tamanho('G');
      cardapio.selecionarSaborPizza(produtos.produtos[0]);
      cardapio.selecionarSaborPizza(produtos.produtos[1]);
      expect(cardapio.calcularPrecoPizza(), regra == 'media' ? 60 : 70);

      cardapio.tamanhosPizza = tamanho('P');
      expect(cardapio.saboresPizzaSelecionados, hasLength(2));
      expect(cardapio.calcularPrecoPizza(), 30);
      expect(cardapio.valorSaborPizza(produtos.produtos[0]), '30');
      expect(produtos.produtos[0].valorVenda, '0');
    });
  }

  test('limpa sabores ao escolher tamanho com limite menor', () {
    cardapio.tamanhosPizza = tamanho('G');
    cardapio.selecionarSaborPizza(produtos.produtos[0]);
    cardapio.selecionarSaborPizza(produtos.produtos[1]);
    cardapio.tamanhosPizza = tamanho('P', limite: 1);
    expect(cardapio.saboresPizzaSelecionados, isEmpty);
    expect(cardapio.calcularPrecoPizza(), 0);
  });

  test('nao mistura produtos sem o tamanho escolhido na pizza', () {
    cardapio.tamanhosPizza = tamanho('G');
    cardapio.selecionarSaborPizza(produtos.produtos.first);
    final incompativel = sabor('Outro sabor', 'Outra categoria', '100')
      ..tamanhosPizza = [];
    cardapio.selecionarSaborPizza(incompativel);
    expect(cardapio.saboresPizzaSelecionados, [produtos.produtos.first]);

    cardapio.tamanhosPizza = tamanho('Familia');
    expect(cardapio.saboresPizzaSelecionados, isEmpty);
  });
}
