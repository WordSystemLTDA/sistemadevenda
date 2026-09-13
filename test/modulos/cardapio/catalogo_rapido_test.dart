import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/favoritos_produtos.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:app/src/modulos/voz/dialogo_pedido_voz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'montagem_pizza_test.dart' as fixture;

class CatalogoRapidoTeste extends fixture.ProdutosTeste {
  CatalogoRapidoTeste() {
    produtos.clear();
    produtos.addAll(List.generate(
        25,
        (i) => fixture.sabor('$i', 'Bebidas', '12')
          ..nome = i == 0 ? 'Água mineral com gás' : 'Suco natural ${i + 1}'
          ..habilTipo = 'Normal'
          ..valorVenda = '8.50'
          ..tamanhosPizza = []));
  }
  bool falhar = false;
  @override
  Future<List<Modelowordprodutos>> listarPorCategoria(
      String categoria, int pagina) async {
    if (falhar) throw StateError('Sem conexao e sem cache');
    return produtos
        .where((p) =>
            p.ativo == 'Sim' && (categoria == '0' || p.categoria == categoria))
        .skip((pagina - 1) * 15)
        .take(15)
        .toList();
  }

  @override
  Future<List<Modelowordprodutos>> listarPorNome(
      String pesquisa, String categoria, String idcliente,
      {bool codigoExato = false}) async {
    if (falhar) throw StateError('Sem conexao e sem cache');
    return produtos
        .where((p) =>
            p.ativo == 'Sim' &&
            (categoria == '0' || p.categoria == categoria) &&
            normalizarBusca('${p.nome} ${p.codigo}')
                .contains(normalizarBusca(pesquisa)))
        .toList();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  late UsuarioProvedor usuarios;
  late ProvedorCardapio cardapio;
  late CatalogoRapidoTeste produtos;
  late FavoritosProdutos favoritos;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    usuarios = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          id: '1',
          empresa: '32',
          configuracoes: fixture.ConfiguracoesTeste('media')));
    cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuarios);
    produtos = CatalogoRapidoTeste();
    favoritos = FavoritosProdutos(usuarios);
    await favoritos.carregar();
    Modular.init(fixture.ModuloTeste(cardapio, usuarios, produtos));
  });
  tearDown(() {
    favoritos.dispose();
    Modular.destroy();
    cardapio.dispose();
    usuarios.dispose();
  });

  Future<void> abrir(WidgetTester tester,
      {Size tela = const Size(393, 852),
      double escala = 1,
      bool escuro = false}) async {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('captura'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: escuro ? Brightness.dark : Brightness.light),
          appBarTheme:
              const AppBarThemeData(actionsPadding: EdgeInsets.only(right: 60)),
        ),
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(escala)),
            child: child!),
        home: const PaginaCardapio(
            tipo: TipoCardapio.comanda,
            id: '10673',
            idComanda: '3',
            nomeAtendimento: 'Comanda 3'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'microfone responde com carrinho cheio e nao inicializa plugin ao abrir',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.byKey(const ValueKey('adicionar_produto_0')));
    await tester.pumpAndSettle();
    final carrinho = Modular.get<ProvedorCarrinho>();
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    final microfone = find.byKey(const ValueKey('pedido_por_voz'));
    final acionar = tester.widget<IconButton>(microfone).onPressed!;
    await tester.tap(microfone);
    acionar(); // Um callback atrasado tambem nao deve abrir outro dialogo.
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DialogoPedidoVoz), findsOneWidget);
    expect(tester.widget<IconButton>(microfone).onPressed, isNull);
    expect(find.textContaining('Entre novamente'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cancelar pedido por voz'));
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(microfone).onPressed, isNotNull);
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    await tester.pumpWidget(const SizedBox());
  }, variant: TargetPlatformVariant({TargetPlatform.iOS}));

  testWidgets(
      'favoritar nao adiciona e filtro inclui produto alem da primeira pagina',
      (tester) async {
    await tester.runAsync(() => favoritos.alternar('24'));
    await abrir(tester);
    final carrinho = Modular.get<ProvedorCarrinho>();
    await tester.tap(find.byKey(const ValueKey('favorito_0')));
    await tester.pumpAndSettle();
    expect(carrinho.itensCarrinho.quantidadeTotal, 0);
    await tester.tap(find.byKey(const ValueKey('filtrar_favoritos')));
    await tester.pumpAndSettle();
    expect(find.text('Suco natural 25'), findsOneWidget);
    expect(find.byType(CardProduto), findsNWidgets(2));
    await tester.tap(find.byKey(const ValueKey('adicionar_produto_24')));
    await tester.pumpAndSettle();
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    expect(carrinho.itensCarrinho.listaComandosPedidos.single.id, '24');
    expect(find.text('Novos itens'), findsOneWidget);
    expect(find.text('Comanda 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('favorito_24')));
    await tester.pumpAndSettle();
    expect(find.text('Suco natural 25'), findsNothing);
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('filtro preserva pesquisa e apresenta erro com nova tentativa',
      (tester) async {
    await tester.runAsync(() => favoritos.alternar('0'));
    await abrir(tester);
    await tester.enterText(find.byType(TextField), 'agua');
    await tester.pumpAndSettle(const Duration(milliseconds: 350));
    await tester.tap(find.byKey(const ValueKey('filtrar_favoritos')));
    await tester.pumpAndSettle();
    expect(find.text('Água mineral com gás'), findsOneWidget);
    produtos.falhar = true;
    await tester.tap(find.byKey(const ValueKey('filtrar_favoritos')));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível pesquisar os produtos.'), findsWidgets);
    produtos.falhar = false;
    await tester.tap(find.byTooltip('Tentar novamente').first);
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível pesquisar os produtos.'), findsNothing);
    expect(find.text('agua'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('atualizacao silenciosa preserva consulta completa e novo preco',
      () async {
    final provedor = ProvedorProdutos(produtos);
    addTearDown(provedor.dispose);
    await provedor.listarProdutosPorNome('', '0', '0');
    expect(provedor.produtos, hasLength(25));
    produtos.produtos[24].valorVenda = '9.90';
    produtos.produtos[0].ativo = 'Não';
    await provedor.atualizarSilenciosamente('0');
    expect(provedor.produtos, hasLength(24));
    expect(provedor.produtos.last.valorVenda, '9.90');
    expect(provedor.temMais, isFalse);
  });

  for (final (tela, escala, escuro) in [
    (const Size(393, 852), 1.0, false),
    (const Size(320, 720), 1.8, false),
    (const Size(820, 1180), 1.0, false),
    (const Size(393, 852), 1.0, true),
  ]) {
    testWidgets('catalogo e favoritos legiveis ${tela.width} $escala $escuro',
        (tester) async {
      await tester.runAsync(() async {
        await favoritos.alternar('0');
        await favoritos.alternar('1');
      });
      await abrir(tester, tela: tela, escala: escala, escuro: escuro);
      await tester.tap(find.byKey(const ValueKey('adicionar_produto_0')));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final botao =
          tester.getRect(find.byKey(const ValueKey('adicionar_produto_0')));
      expect(botao.width, greaterThanOrEqualTo(48));
      expect(botao.height, greaterThanOrEqualTo(48));
      await capturarTela(
          tester, 'catalogo_etapa2_${tela.width}_${escala}_$escuro');
      await tester.tap(find.byKey(const ValueKey('filtrar_favoritos')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturarTela(
          tester, 'favoritos_etapa2_${tela.width}_${escala}_$escuro');
      await tester.pumpWidget(const SizedBox());
    });
  }
}
