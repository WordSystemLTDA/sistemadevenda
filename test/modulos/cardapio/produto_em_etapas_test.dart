import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'montagem_pizza_test.dart' as fixture;

class ProdutosEtapasTeste extends fixture.ProdutosTeste {
  final acai = fixture.sabor('acai', 'Acai', '32')
    ..nome = 'Açaí no Copo'
    ..habilTipo = 'Pacote'
    ..tamanhosPizza = []
    ..valorVenda = '32'
    ..opcoesPacotes = [
      ModeloOpcoesPacotes(
        id: 7,
        tipo: 3,
        titulo: 'Selecione os Adicionais',
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(id: 'creme', nome: 'Creme', valor: '6'),
          ModeloDadosOpcoesPacotes(id: 'banana', nome: 'Banana', valor: '3'),
        ],
      ),
      ModeloOpcoesPacotes(
        id: 5,
        tipo: 2,
        titulo: 'Selecione os Acompanhamentos',
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
              id: 'leite', nome: 'Leite Condensado', valor: '0'),
          ModeloDadosOpcoesPacotes(id: 'po', nome: 'Leite em Pó', valor: '0'),
        ],
      ),
      ModeloOpcoesPacotes(
        id: 4,
        tipo: 1,
        titulo: 'Selecione um Tamanho',
        obrigatorio: true,
        dados: [
          ModeloDadosOpcoesPacotes(id: '500', nome: 'Copo 500ml', valor: '32'),
          ModeloDadosOpcoesPacotes(id: '700', nome: 'Copo 700ml', valor: '45'),
        ],
      ),
    ];

  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho,
      {bool modeloRecorrente = false}) async {
    consultasPorId.add((id, tamanho));
    return Modelowordprodutos.fromMap(acai.toMap());
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  late UsuarioProvedor usuario;
  late ProvedorCardapio cardapio;
  late ProdutosEtapasTeste produtos;
  final salvos = <Modelowordprodutos>[];

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: fixture.ConfiguracoesTeste('media')));
    cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
    produtos = ProdutosEtapasTeste();
    salvos.clear();
    Modular.init(fixture.ModuloTeste(cardapio, usuario, produtos));
  });

  tearDown(() {
    Modular.destroy();
    cardapio.dispose();
    usuario.dispose();
  });

  Future<void> abrir(WidgetTester tester,
      {Size tamanho = const Size(430, 932), double escala = 1}) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
      key: const ValueKey('captura'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          fontFamily: 'Roboto',
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PaginaProduto(
                    produto: produtos.acai,
                    inserirEmItensRecorrentes: salvos.add,
                  ),
                ),
              ),
              child: const Text('Abrir produto'),
            ),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir produto'));
    await tester.pumpAndSettle();
  }

  Future<void> tocar(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> avancar(WidgetTester tester) =>
      tocar(tester, find.byKey(const Key('avancar_etapa_produto')));

  testWidgets('separa etapas, conserva escolhas ao voltar e salva uma vez',
      (tester) async {
    await abrir(tester);
    final provedor = Modular.get<ProvedorProduto>();
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('Copo 500ml'), findsOneWidget);
    expect(find.text('Leite Condensado'), findsNothing);
    expect(find.text('Creme'), findsNothing);
    expect(find.byKey(const Key('adicionar_produto_carrinho')), findsNothing);

    await tocar(tester, find.text('Copo 500ml'));
    await tocar(tester, find.byTooltip('Aumentar quantidade do produto'));
    await avancar(tester);
    expect(find.text('2 de 3'), findsOneWidget);
    expect(find.text('Copo 500ml'), findsNothing);
    expect(find.text('Leite Condensado'), findsOneWidget);
    expect(find.text('Creme'), findsNothing);
    await tocar(tester, find.text('Leite em Pó'));
    await avancar(tester);

    expect(find.text('3 de 3'), findsOneWidget);
    expect(find.text('Leite Condensado'), findsNothing);
    await tocar(tester, find.byTooltip('Aumentar Creme'));
    await tocar(tester, find.byTooltip('Aumentar Creme'));
    await tocar(tester, find.byTooltip('Aumentar Banana'));
    expect(provedor.valorVenda, 47);
    expect(provedor.quantidade, 2);

    await tocar(tester, find.byType(BackButton));
    expect(find.text('2 de 3'), findsOneWidget);
    expect(provedor.retornarDadosPorID([5], false, '0').single.id, 'leite');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('1 de 3'), findsOneWidget);
    await tocar(tester, find.text('Copo 700ml'));
    expect(provedor.valorVenda, 60);
    await avancar(tester);
    await avancar(tester);
    expect(provedor.retornarDadosPorID([7], false, '0').first.quantidade, 2);
    final obs = find.byKey(const Key('observacao_adicionais_produto'));
    await tester.ensureVisible(obs);
    await tester.enterText(obs, 'Pouco leite');
    await tester.pumpAndSettle();
    await tocar(tester, find.byKey(const Key('adicionar_produto_carrinho')));

    expect(salvos, hasLength(1));
    expect(salvos.single.valorVenda, '60.00');
    expect(salvos.single.quantidade, 2);
    expect(salvos.single.observacao, 'Pouco leite');
    expect(
        salvos.single.opcoesPacotesListaFinal!
            .firstWhere((grupo) => grupo.id == 4)
            .dados!
            .single
            .id,
        '700');
    expect(produtos.consultasPorId, hasLength(1));
    expect(find.text('Abrir produto'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('valida tamanho e impede que toques rapidos pulem etapas',
      (tester) async {
    await abrir(tester);
    await avancar(tester);
    expect(
        find.text('Selecione um tamanho antes de continuar.'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    await tocar(tester, find.text('Copo 500ml'));
    final botao = find.byKey(const Key('avancar_etapa_produto'));
    await tester.tap(botao);
    await tester.pump(const Duration(milliseconds: 30));
    await tester.tap(botao);
    await tester.pumpAndSettle();
    expect(find.text('2 de 3'), findsOneWidget);
    expect(salvos, isEmpty);
    expect(produtos.consultasPorId, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'pula acompanhamentos inexistentes e limpa busca sem perder escolhas',
      (tester) async {
    produtos.acai.opcoesPacotes!.removeWhere((grupo) => grupo.id == 5);
    await abrir(tester);
    expect(find.text('1 de 2'), findsOneWidget);
    await tocar(tester, find.text('Copo 500ml'));
    await avancar(tester);
    expect(find.text('2 de 2'), findsOneWidget);
    final busca = find.byKey(const ValueKey('pesquisa_opcoes_produto'));
    await tester.ensureVisible(busca);
    await tester.enterText(busca, 'Banana');
    await tester.pumpAndSettle();
    expect(find.text('Creme'), findsNothing);
    await tocar(tester, find.byTooltip('Aumentar Banana'));
    await tocar(tester, find.byType(BackButton));
    await avancar(tester);
    expect(tester.widget<TextField>(busca).controller!.text, isEmpty);
    expect(find.text('Creme'), findsOneWidget);
    expect(Modular.get<ProvedorProduto>().valorVenda, 35);
    expect(produtos.consultasPorId, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (largura, escala) in [(320.0, 2.0), (430.0, 1.0), (800.0, 1.3)]) {
    testWidgets('etapas cabem em $largura com escala $escala', (tester) async {
      await abrir(tester, tamanho: Size(largura, 932), escala: escala);
      await capturarTela(tester, 'produto_etapas_tamanho_$largura');
      await tocar(tester, find.text('Copo 500ml'));
      await avancar(tester);
      await capturarTela(tester, 'produto_etapas_acompanhamentos_$largura');
      await avancar(tester);
      await capturarTela(tester, 'produto_etapas_adicionais_$largura');
      expect(find.byKey(const Key('adicionar_produto_carrinho')).hitTestable(),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
