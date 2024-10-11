import 'package:app/src/modulos/cardapio/modelos/categoria_model.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';

class ProvedorCardapio extends ChangeNotifier {
  final ServicosCategoria _categoriaService;
  final ServicoProduto _produtoService;

  ProvedorCardapio(this._categoriaService, this._produtoService);

  List<CategoriaModel> categorias = [];
  List<ModeloProduto> produtos = [];

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
