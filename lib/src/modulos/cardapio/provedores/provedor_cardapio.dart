import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';

class ProvedorCardapio extends ChangeNotifier {
  final ServicosCategoria _categoriaService;
  final ServicoProduto _produtoService;

  ProvedorCardapio(this._categoriaService, this._produtoService);

  ModeloTamanhosPizza? _tamanhosPizza;
  ModeloTamanhosPizza? get tamanhosPizza => _tamanhosPizza;
  set tamanhosPizza(ModeloTamanhosPizza? value) {
    _tamanhosPizza = value;
    notifyListeners();
  }

  List<ModeloProduto> _saboresPizzaSelecionados = [];
  List<ModeloProduto> get saboresPizzaSelecionados => _saboresPizzaSelecionados;
  set saboresPizzaSelecionados(List<ModeloProduto> value) {
    _saboresPizzaSelecionados = value;
    notifyListeners();
  }

  List<ModeloCategoria> _categorias = [];
  List<ModeloCategoria> get categorias => _categorias;
  set categorias(List<ModeloCategoria> value) {
    _categorias = value;
    notifyListeners();
  }

  List<ModeloProduto> _produtos = [];
  List<ModeloProduto> get produtos => _produtos;
  set produtos(List<ModeloProduto> value) {
    _produtos = value;
    notifyListeners();
  }

  void resetarTudo() {
    saboresPizzaSelecionados = [];
    tamanhosPizza = null;
    categorias = [];
    produtos = [];
    notifyListeners();
  }

  void listarCategorias() async {
    final res = await _categoriaService.listar();
    categorias = res;
    notifyListeners();
  }

  Future<void> listarProdutosPorCategoria(String category) async {
    final res = await _produtoService.listarPorCategoria(category);
    if (res.isEmpty) return;

    produtos = res;
    notifyListeners();
  }

  Future<List<ModeloProduto>> listarProdutosPorNome(String pesquisa, String categoria, String idcliente) async {
    return await _produtoService.listarPorNome(pesquisa, categoria, idcliente);
  }
}
