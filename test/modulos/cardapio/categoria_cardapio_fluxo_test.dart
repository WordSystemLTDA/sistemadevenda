import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_ingredientes_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/etapa_montagem_cardapio.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:dio/dio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montagem_pizza_test.dart' as fixture;
import '../../suporte/captura_tela.dart';

class ProdutosCategoriaCardapioTeste extends fixture.ProdutosTeste {
  ServicoProduto? servicoReal;
  bool omitirMontagem = false;
  bool semIngredientes = false;
  final produtoCardapio = Modelowordprodutos(
    id: '151',
    nome: 'Almoço Livre',
    codigo: '151',
    estoque: '0',
    tamanho: '',
    foto: '',
    ativo: 'Sim',
    descricao: '',
    valorVenda: '45.00',
    categoria: 'Almoço',
    nomeCategoria: 'Almoço',
    habilTipo: '',
    idCategoriaCardapio: '9',
    ingredientes: const [],
  );

  ProdutosCategoriaCardapioTeste() {
    produtos.add(produtoCardapio);
  }

  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho) async {
    if (servicoReal != null) return servicoReal!.listarPorId(id, tamanho);
    consultasPorId.add((id, tamanho));
    if (id != produtoCardapio.id) return super.listarPorId(id, tamanho);
    return Modelowordprodutos.fromMap(produtoCardapio.toMap())
      ..opcoesPacotes = [
        if (!omitirMontagem)
          ModeloOpcoesPacotes(
            id: 12,
            titulo: 'Ingredientes do Cardápio',
            tipo: 8,
            obrigatorio: false,
            dados: semIngredientes
                ? []
                : [
                    ModeloDadosOpcoesPacotes(
                      id: '1',
                      nome: 'Arroz',
                      valor: '0',
                      idCategoriaCardapio: '9',
                    ),
                    ModeloDadosOpcoesPacotes(
                      id: '2',
                      nome: 'Feijão',
                      valor: '0',
                      idCategoriaCardapio: '9',
                    ),
                  ],
          ),
      ];
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);

  late UsuarioProvedor usuario;
  late ProvedorCardapio cardapio;
  late ProdutosCategoriaCardapioTeste produtos;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
        empresa: '32',
        configuracoes: fixture.ConfiguracoesTeste('media'),
      ));
    cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
    produtos = ProdutosCategoriaCardapioTeste();
    Modular.init(fixture.ModuloTeste(cardapio, usuario, produtos));
  });

  tearDown(() {
    Modular.destroy();
    cardapio.dispose();
    usuario.dispose();
  });

  testWidgets(
      'produto com categoria_cardapio abre montagem antes dos adicionais',
      (tester) async {
    final produtoCatalogo = Modelowordprodutos.fromMap({
      ...produtos.produtoCardapio.toMap(),
      'idCategoriaCardapio': null,
      'categoriaCardapio': null,
      'id_categoria_cardapio': null,
      'categoria_cardapio': '9',
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CardProduto(
          estaPesquisando: false,
          item: produtoCatalogo,
          categoria: null,
          finalizar: false,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(CardProduto));
    await tester.pumpAndSettle();

    expect(produtos.consultasPorId.single, ('151', '0'));
    expect(find.text('Montagem do produto'), findsOneWidget);
    expect(find.text('Almoço Livre'), findsOneWidget);
    expect(find.text('Normal'), findsWidgets);
    expect(Modular.get<ProvedorCarrinho>().itensCarrinho.listaComandosPedidos,
        isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('produto vinculado nao pula montagem quando API omite o grupo',
      (tester) async {
    produtos.omitirMontagem = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CardProduto(
      estaPesquisando: false,
      item: produtos.produtoCardapio,
      categoria: null,
      finalizar: false,
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CardProduto));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(
        find.textContaining('Adicionar ao', findRichText: true), findsNothing);
    produtos.omitirMontagem = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.byType(EtapaMontagemCardapio), findsOneWidget);
  });

  testWidgets('categoria sem ingredientes do dia informa indisponibilidade',
      (tester) async {
    produtos.semIngredientes = true;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: CardProduto(
      estaPesquisando: false,
      item: produtos.produtoCardapio,
      categoria: null,
      finalizar: false,
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CardProduto));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum ingrediente disponível hoje.'), findsOneWidget);
    expect(
        tester.widget<BotaoAcaoPedido>(find.byType(BotaoAcaoPedido)).habilitado,
        isFalse);
    expect(
        find.textContaining('Adicionar ao', findRichText: true), findsNothing);
  });

  for (final largura in [390.0, 834.0]) {
    testWidgets(
        'Almoco 436: montagem, troca, adicionais e carrinho em $largura',
        (tester) async {
      tester.view.physicalSize = Size(largura, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final resposta = jsonDecode(
          File('test/fixtures/almoco_livre_cardapio.json').readAsStringSync());
      final api = DioCliente(servidor: 'http://servidor/api1/');
      addTearDown(() => api.cliente.close(force: true));
      api.cliente.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          expect(options.uri.queryParameters['id'], '436');
          handler.resolve(Response(
              requestOptions: options, statusCode: 200, data: resposta));
        },
      ));
      produtos.servicoReal = ServicoProduto(api, usuario);
      cardapio.tipo = TipoCardapio.comanda;
      cardapio.idComanda = '4';
      await Modular.get<ProvedorCarrinho>().selecionarAtendimento(
          tipo: 'comanda', idAtendimento: '104', idRecurso: '4');
      final catalogo = Modelowordprodutos.fromMap({
        ...resposta as Map<String, dynamic>,
        'habilTipo': 'Não',
        'opcoesPacotes': null,
      });
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
            home: Scaffold(
                body: CardProduto(
          estaPesquisando: false,
          item: catalogo,
          categoria: null,
          finalizar: false,
        ))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CardProduto));
      await tester.pumpAndSettle();
      expect(find.byType(EtapaMontagemCardapio), findsOneWidget);
      final cards = tester
          .widgetList<CardIngredientesCardapio>(
              find.byType(CardIngredientesCardapio))
          .toList();
      expect(cards, hasLength(3));
      expect(cards.map((card) => card.item.montagemCardapio!.acao),
          everyElement(AcaoIngredienteCardapio.normal));
      expect(find.text('Selecione os Adicionais'), findsNothing);
      await capturarTela(tester, 'almoco_montagem_${largura.toInt()}');

      Finder ingrediente(String nome) => find.ancestor(
          of: find.text(nome), matching: find.byType(CardIngredientesCardapio));
      await tester.tap(find.descendant(
          of: ingrediente('Feijão'), matching: find.text('Pouco')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: ingrediente('Carne de Panela'), matching: find.text('Trocar')));
      await tester.pumpAndSettle();
      expect(find.byType(EtapaTrocaCardapio), findsOneWidget);
      await tester.tap(find.text('Arroz'));
      await tester.pumpAndSettle();
      await capturarTela(tester, 'almoco_troca_${largura.toInt()}');
      await tester.tap(find.byType(BotaoAcaoPedido));
      await tester.pumpAndSettle();
      expect(find.byType(EtapaMontagemCardapio), findsOneWidget);
      expect(find.text('Trocar por 1x Arroz'), findsOneWidget);
      await tester.tap(find.byType(BotaoAcaoPedido));
      await tester.pumpAndSettle();
      expect(find.text('Selecione os Adicionais'), findsOneWidget);
      await tester.tap(find.text('Ovo'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Adicionar ao', findRichText: true));
      await tester.pumpAndSettle();
      final itens =
          Modular.get<ProvedorCarrinho>().itensCarrinho.listaComandosPedidos;
      expect(itens, hasLength(1));
      final item = itens.single;
      expect(item.idCategoriaCardapio, '3');
      final montagem =
          item.opcoesPacotesListaFinal!.singleWhere((g) => g.tipo == 8).dados!;
      expect(montagem.map((i) => i.montagemCardapio!.acao), [
        AcaoIngredienteCardapio.normal,
        AcaoIngredienteCardapio.trocar,
        AcaoIngredienteCardapio.pouco,
      ]);
      expect(montagem.every((i) => i.valor == '0'), isTrue);
      expect(
          item.opcoesPacotesListaFinal!
              .singleWhere((g) => g.id == 7)
              .dados!
              .single
              .valor,
          '1.00');
      final impressao = DadosImpressaoPreparo.produto(item);
      final grupoImpresso = (impressao['opcoesPacotesListaFinal'] as List)
          .singleWhere((g) => g['tipo'] == 8);
      expect(grupoImpresso['dados'][1]['nome'],
          'TROCAR Carne de Panela POR 1x Arroz');
      expect(grupoImpresso['dados'][2]['nome'], 'POUCO Feijão');
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
            home: Scaffold(
                body: SingleChildScrollView(
          child: CardCarrinho(
            item: item,
            index: 0,
            idComanda: '4',
            idMesa: '0',
            value: null,
            setarQuantidade: (_) async => true,
            aoExcluirItem: () {},
          ),
        ))),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mostrar detalhes'));
      await tester.pumpAndSettle();
      expect(find.text('Ingredientes do Cardápio'), findsOneWidget);
      expect(find.text('Trocar por 1x Arroz'), findsOneWidget);
      expect(find.text('Pouco'), findsOneWidget);
      expect(find.textContaining('TROCAR Carne'), findsNothing);
      await capturarTela(tester, 'almoco_carrinho_${largura.toInt()}');
      expect(tester.takeException(), isNull);
    });
  }
}
