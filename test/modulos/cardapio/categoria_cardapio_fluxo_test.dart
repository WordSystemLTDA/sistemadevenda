import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'montagem_pizza_test.dart' as fixture;

class ProdutosCategoriaCardapioTeste extends fixture.ProdutosTeste {
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
    consultasPorId.add((id, tamanho));
    if (id != produtoCardapio.id) return super.listarPorId(id, tamanho);
    return Modelowordprodutos.fromMap(produtoCardapio.toMap())
      ..opcoesPacotes = [
        ModeloOpcoesPacotes(
          id: 12,
          titulo: 'Ingredientes do Cardápio',
          tipo: 8,
          obrigatorio: false,
          dados: [
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
}
