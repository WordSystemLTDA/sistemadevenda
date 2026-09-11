import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DioClienteTeste extends Fake implements DioCliente {}

class ModuloCarrinhoTeste extends Module {
  final ProvedorCarrinho carrinho;

  ModuloCarrinhoTeste(this.carrinho);

  @override
  void binds(Injector i) {
    i.addInstance<ProvedorCarrinho>(carrinho);
  }
}

Modelowordprodutos produtoCarrinho({double quantidade = 1}) {
  return Modelowordprodutos(
    id: '1010',
    nome: 'Coca Cola 2L',
    codigo: '1010',
    estoque: '0',
    tamanho: '',
    foto: '',
    ativo: 'Sim',
    descricao: '',
    valorVenda: '10',
    categoria: 'Bebidas',
    nomeCategoria: 'Bebidas',
    habilTipo: '',
    ingredientes: [],
    quantidade: quantidade,
  );
}

Future<void> carregarCard(
  WidgetTester tester, {
  required Modelowordprodutos item,
  required Future<bool> Function(bool increase) setarQuantidade,
  VoidCallback? aoExcluirItem,
}) async {
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
    home: Scaffold(
      body: Center(
        child: CardCarrinho(
          item: item,
          index: 0,
          idComanda: '3',
          idMesa: '0',
          value: '',
          setarQuantidade: setarQuantidade,
          aoExcluirItem: aoExcluirItem ?? () {},
        ),
      ),
    ),
  ));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(Modular.destroy);

  testWidgets('confirma antes de aumentar e diminuir quantidade',
      (tester) async {
    final carrinho = ProvedorCarrinho(ServicosItensComanda(DioClienteTeste(),
        UsuarioProvedor()..setUsuario(UsuarioModelo(empresa: '32'))));
    addTearDown(carrinho.dispose);
    Modular.init(ModuloCarrinhoTeste(carrinho));
    final item = produtoCarrinho();
    var alteracoes = 0;

    await carregarCard(
      tester,
      item: item,
      setarQuantidade: (increase) async {
        alteracoes++;
        item.quantidade = item.quantidade! + (increase ? 1 : -1);
        return true;
      },
    );

    await tester.tap(find.byTooltip('Aumentar quantidade'));
    await tester.pumpAndSettle();
    expect(find.text('Adicionar mais uma unidade?'), findsOneWidget);
    expect(find.text('Atual'), findsOneWidget);
    expect(find.text('Nova'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    final acoes = tester
        .getRect(find.byKey(const ValueKey('confirmacao_carrinho_acoes')));
    final botaoAdicionar =
        tester.getRect(find.byKey(const ValueKey('confirmacao_carrinho_acao')));
    expect((botaoAdicionar.right - acoes.right).abs(), lessThan(1));
    final campoNova = tester
        .getRect(find.byKey(const ValueKey('quantidade_confirmacao_Nova')));
    final numeroNova = tester.getRect(find.text('2'));
    expect((numeroNova.center.dx - campoNova.center.dx).abs(), lessThan(1));

    await tester
        .tap(find.byKey(const ValueKey('confirmacao_carrinho_cancelar')));
    await tester.pumpAndSettle();
    expect(alteracoes, 0);
    expect(item.quantidade, 1);

    await tester.tap(find.byTooltip('Aumentar quantidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmacao_carrinho_acao')));
    await tester.pumpAndSettle();
    expect(alteracoes, 1);
    expect(item.quantidade, 2);

    await tester.tap(find.byTooltip('Diminuir quantidade'));
    await tester.pumpAndSettle();
    expect(find.text('Diminuir uma unidade?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirmacao_carrinho_acao')));
    await tester.pumpAndSettle();
    expect(alteracoes, 2);
    expect(item.quantidade, 1);
    expect(find.byTooltip('Excluir item'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lixeira exclui item somente depois da confirmacao',
      (tester) async {
    final carrinho = ProvedorCarrinho(ServicosItensComanda(DioClienteTeste(),
        UsuarioProvedor()..setUsuario(UsuarioModelo(empresa: '32'))));
    addTearDown(carrinho.dispose);
    Modular.init(ModuloCarrinhoTeste(carrinho));
    final item = produtoCarrinho();
    await carrinho.selecionarAtendimento(
        tipo: 'comanda', idAtendimento: '10673', idRecurso: '3');
    await carrinho.inserir(item, 'Comanda', '0', '3', '10', '', item.id,
        item.nome, item.quantidade, '');
    var excluiu = false;

    await carregarCard(
      tester,
      item: carrinho.itensCarrinho.listaComandosPedidos.single,
      setarQuantidade: (_) async => true,
      aoExcluirItem: () => excluiu = true,
    );

    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir item?'), findsOneWidget);

    await tester
        .tap(find.byKey(const ValueKey('confirmacao_carrinho_cancelar')));
    await tester.pumpAndSettle();
    expect(excluiu, isFalse);
    expect(carrinho.itensCarrinho.listaComandosPedidos, hasLength(1));

    await tester.tap(find.byTooltip('Excluir item'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirmacao_carrinho_acao')));
    await tester.pumpAndSettle();
    expect(excluiu, isTrue);
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(tester.takeException(), isNull);
  });
}
