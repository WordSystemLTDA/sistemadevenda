import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'card_carrinho_test.dart' as carrinho_fixture;
import 'montagem_pizza_test.dart' as pizza_fixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  late ProvedorCardapio cardapio;
  late pizza_fixture.ProdutosTeste produtos;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32',
          configuracoes: pizza_fixture.ConfiguracoesTeste('media')));
    cardapio = ProvedorCardapio(pizza_fixture.CategoriasTeste(), usuario);
    produtos = pizza_fixture.ProdutosTeste();
    Modular.init(pizza_fixture.ModuloTeste(cardapio, usuario, produtos));
  });
  tearDown(Modular.destroy);

  for (final (tela, escala) in [
    (const Size(320, 568), 1.0),
    (const Size(360, 640), 1.3),
    (const Size(393, 852), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(568, 320), 1.3),
    (const Size(800, 1024), 1.6),
  ]) {
    final cenario = '${tela.width.toInt()}x${tela.height.toInt()}_$escala';

    Future<void> abrir(WidgetTester tester, Widget pagina) async {
      tester.view.physicalSize = tela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!,
          ),
          home: pagina,
        ),
      ));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        final context = tester.element(find.byType(Scaffold).first);
        await precacheImage(const AssetImage(Assets.produtoAsset), context);
        if (context.mounted) {
          await precacheImage(const AssetImage(Assets.boxAsset), context);
        }
      });
      await tester.pump();
    }

    testWidgets('cardapio permite montar pizza sem cortes em $cenario',
        (tester) async {
      await abrir(
          tester,
          const PaginaCardapio(
              tipo: TipoCardapio.comanda, id: '10673', idComanda: '3'));
      await capturarTela(tester, 'responsivo_tamanhos_$cenario');
      final tamanhos = find.descendant(
          of: find.byType(ListaTamanhosPizza), matching: find.byType(InkWell));
      for (final opcao in tamanhos.evaluate().toList()) {
        final finder = find.byElementPredicate((e) => e == opcao);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final rect = tester.getRect(finder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(tela.width));
      }
      final grande = find.descendant(
          of: find.byType(ListaTamanhosPizza), matching: find.text('G'));
      await tester.ensureVisible(grande);
      await tester.tap(grande);
      await tester.pumpAndSettle();
      expect(cardapio.tamanhosPizza?.id, 'G');
      if (find.byType(CardProduto).evaluate().isEmpty) {
        await tester.drag(
            find.byType(CustomScrollView).first, const Offset(0, -120));
        await tester.pumpAndSettle();
      }
      final sabor = find.byType(CardProduto).first;
      final selecionar =
          find.descendant(of: sabor, matching: find.byType(IconButton)).last;
      await tester.ensureVisible(selecionar);
      await tester.pumpAndSettle();
      await tester.tap(selecionar);
      await tester.pumpAndSettle();
      expect(cardapio.saboresPizzaSelecionados, hasLength(1));
      expect(find.byType(BotaoAcaoPedido), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'responsivo_cardapio_$cenario');

      await tester.tap(find.byType(BotaoAcaoPedido));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BotaoAcaoPedido));
      await tester.pumpAndSettle();
      expect(find.byType(PaginaProduto), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'responsivo_produto_$cenario');
      await tester.tap(find.byType(BotaoAcaoPedido));
      await tester.pumpAndSettle();
      expect(Modular.get<ProvedorCarrinho>().itensCarrinho.listaComandosPedidos,
          hasLength(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('bordas e adicionais longos permanecem acessiveis em $cenario',
        (tester) async {
      cardapio.configBigchef = pizza_fixture.configBigchef();
      cardapio.tamanhosPizza = pizza_fixture.tamanho('Grande tamanho familia');
      final provedor = Modular.get<ProvedorProduto>();
      final borda = ModeloDadosOpcoesPacotes(
          id: '1', nome: 'Catupiry especial com queijo e ervas', valor: '12');
      final adicional = ModeloDadosOpcoesPacotes(
          id: '2',
          nome: 'Chocolate branco com pedacos de morango',
          valor: '15',
          quantidade: 1);
      final opcoes = [
        ModeloOpcoesPacotes(
            id: 6, titulo: 'Bordas', obrigatorio: false, dados: [borda]),
        ModeloOpcoesPacotes(
            id: 7,
            titulo: 'Adicionais',
            obrigatorio: false,
            dados: [adicional]),
      ];
      provedor.opcoesPacotesListaFinal = opcoes;
      await abrir(
          tester,
          Scaffold(
              body: SingleChildScrollView(
            child: ListenableBuilder(
                listenable: provedor,
                builder: (context, _) => Column(children: [
                      const ListaBordas(),
                      for (final opcao in opcoes)
                        CardOpcoesPacotes(
                            kit: false,
                            opcoesPacote: opcao,
                            item: opcao.dados!.first,
                            idProduto: '0'),
                    ])),
          )));
      expect(tester.takeException(), isNull);
      for (final texto in find.byType(RichText).evaluate()) {
        final render = texto.renderObject as RenderParagraph;
        expect(render.didExceedMaxLines, isFalse);
      }
      await tester.ensureVisible(find.byType(CardOpcoesPacotes).last);
      await tester.pumpAndSettle();
      final controle = find.descendant(
          of: find.byType(CardOpcoesPacotes).last,
          matching: find.byIcon(Icons.remove_circle_outline));
      if (controle.evaluate().isNotEmpty) {
        final menos = tester.getCenter(controle);
        final mais = tester.getCenter(find.descendant(
            of: find.byType(CardOpcoesPacotes).last,
            matching: find.byIcon(Icons.add_circle_outline)));
        final card = tester.getRect(find.byType(CardOpcoesPacotes).last);
        expect((menos.dx + mais.dx) / 2, closeTo(card.center.dx, 1));
        expect(mais.dx - menos.dx, lessThan(110));
      }
      await capturarTela(tester, 'responsivo_opcoes_$cenario');
      expect(tester.takeException(), isNull);
    });

    testWidgets('carrinho e confirmacao com nome longo em $cenario',
        (tester) async {
      final item = carrinho_fixture.produtoCarrinho()
        ..nome = 'Pizza de queijos especiais com mussarela e catupiry'
        ..valorVenda = '1234.56'
        ..opcoesPacotesListaFinal = [
          ModeloOpcoesPacotes(
            id: 7,
            titulo: 'Adicionais',
            obrigatorio: false,
            dados: [
              ModeloDadosOpcoesPacotes(
                  id: '1',
                  nome: 'Chocolate branco com pedacos de morango',
                  valor: '15')
            ],
          )
        ];
      await abrir(
          tester,
          Scaffold(
              body: SingleChildScrollView(
                  child: CardCarrinho(
            item: item,
            index: 0,
            idComanda: '3',
            idMesa: '0',
            value: '',
            setarQuantidade: (aumentar) async {
              item.quantidade = item.quantidade! + (aumentar ? 1 : -1);
              return true;
            },
            aoExcluirItem: () {},
          ))));
      await tester.tap(find.byTooltip('Mostrar detalhes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'responsivo_carrinho_$cenario');
      final aumentar = find.byTooltip('Aumentar quantidade');
      await tester.ensureVisible(aumentar);
      await tester.tap(aumentar);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final confirmar = find.byKey(const ValueKey('confirmacao_carrinho_acao'));
      await tester.ensureVisible(confirmar);
      await tester.pumpAndSettle();
      await capturarTela(tester, 'responsivo_alerta_$cenario');
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(item.quantidade, 2);
      expect(tester.takeException(), isNull);
    });
  }
}
