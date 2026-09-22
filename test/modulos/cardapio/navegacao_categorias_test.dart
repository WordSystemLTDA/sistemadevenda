import 'dart:async';
import 'package:app/src/essencial/api/socket/eventos_catalogo.dart';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montagem_pizza_test.dart'
    show CategoriasTeste, ConfiguracoesTeste, ModuloTeste, ProdutosTeste, sabor;

class CategoriasPendentes extends CategoriasTeste {
  final resposta = Completer<List<ModeloCategoria>>();

  @override
  Future<List<ModeloCategoria>> listar() => resposta.future;
}

class CategoriasComFalha extends CategoriasTeste {
  var tentativas = 0;

  @override
  Future<List<ModeloCategoria>> listar() async {
    if (++tentativas == 1) throw TimeoutException('Sem resposta');
    return categorias;
  }
}

class ProdutosPendentes extends ProdutosTeste {
  final respostas = <String, Completer<List<Modelowordprodutos>>>{};

  @override
  Future<List<Modelowordprodutos>> listarPorCategoria(
      String categoria, int pagina) {
    consultasPorCategoria.add((categoria, pagina));
    return respostas
        .putIfAbsent(categoria, Completer<List<Modelowordprodutos>>.new)
        .future;
  }
}

void main() {
  late UsuarioProvedor usuario;
  late ProvedorCardapio cardapio;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: ConfiguracoesTeste('media')));
  });

  tearDown(() {
    Modular.destroy();
    cardapio.dispose();
    usuario.dispose();
  });

  Future<void> abrir(WidgetTester tester,
      {CategoriasTeste? categorias, ProdutosTeste? produtos}) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    cardapio = ProvedorCardapio(categorias ?? CategoriasTeste(), usuario);
    Modular.init(ModuloTeste(cardapio, usuario, produtos ?? ProdutosTeste()));
    await tester.pumpWidget(const MaterialApp(
        home: PaginaCardapio(
            tipo: TipoCardapio.comanda, id: '10673', idComanda: '3')));
    await tester.pump();
  }

  testWidgets('deslizar para bebidas encerra a montagem sem quebrar a aba',
      (tester) async {
    await abrir(tester);
    await tester.pumpAndSettle();
    final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    controller.animateTo(3);
    await tester.pumpAndSettle();
    cardapio.tamanhosPizza = cardapio.categorias[3].tamanhosPizza!.last;
    cardapio.selecionarSaborPizza(sabor('Chocolate', 'Doces', '90'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-350, 0));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.index, 4);
    expect(cardapio.tamanhosPizza, isNull);
    expect(cardapio.saboresPizzaSelecionados, isEmpty);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('evento atualiza produto novo sem descartar a pizza em montagem',
      (tester) async {
    final produtos = ProdutosTeste();
    await abrir(tester, produtos: produtos);
    await tester.pumpAndSettle();
    final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    controller.animateTo(1);
    await tester.pumpAndSettle();
    cardapio.tamanhosPizza = cardapio.categorias[1].tamanhosPizza!.last;
    cardapio.selecionarSaborPizza(produtos.produtos.first);
    produtos.produtos.add(sabor('Pizza nova', 'Queijos', '50'));
    EventosCatalogo.notificar('produtos');
    await tester.pumpAndSettle();
    expect(find.text('Pizza nova'), findsOneWidget);
    expect(controller.index, 1);
    expect(cardapio.tamanhosPizza?.id, 'G');
    expect(cardapio.saboresPizzaSelecionados, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'trocas rapidas com consultas pendentes mantem a ultima categoria',
      (tester) async {
    final produtos = ProdutosPendentes();
    await abrir(tester, produtos: produtos);
    for (var i = 0; i < 10 && find.byType(TabBar).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    final controller = tester.widget<TabBar>(find.byType(TabBar)).controller!;
    for (final index in [1, 3, 2, 4, 1]) {
      controller.animateTo(index);
      await tester.pump(const Duration(milliseconds: 80));
    }
    await tester.pump(const Duration(seconds: 1));
    for (final entry in produtos.respostas.entries) {
      entry.value.complete([sabor('Produto ${entry.key}', entry.key, '50')]);
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(controller.index, 1);
    expect(controller.indexIsChanging, isFalse);
    expect(controller.offset, closeTo(0, 0.001));
    expect(find.text('Produto Queijos'), findsOneWidget);
    final card = find.ancestor(
        of: find.text('Produto Queijos'), matching: find.byType(CardProduto));
    expect(tester.getRect(card).left, greaterThanOrEqualTo(0));
    expect(tester.getRect(card).right, lessThanOrEqualTo(393));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'sair durante a consulta de categorias nao cria controller descartado',
      (tester) async {
    final categorias = CategoriasPendentes();
    await abrir(tester, categorias: categorias);
    await tester.pumpWidget(const SizedBox.shrink());
    categorias.resposta.complete(categorias.categorias);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha inicial permite tentar novamente e abrir os produtos',
      (tester) async {
    final categorias = CategoriasComFalha();
    await abrir(tester, categorias: categorias);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(categorias.tentativas, 2);
    expect(find.text('Mussarela'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('categorias vazias encerram o carregamento', (tester) async {
    final categorias = CategoriasTeste()..categorias.clear();
    await abrir(tester, categorias: categorias);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Nenhuma categoria encontrada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
