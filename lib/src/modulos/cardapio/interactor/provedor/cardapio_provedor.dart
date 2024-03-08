import 'package:app/src/modulos/cardapio/data/services/categoria_service_impl.dart';
import 'package:app/src/modulos/cardapio/data/services/produto_service_impl.dart';
import 'package:app/src/modulos/cardapio/interactor/models/categoria_model.dart';
import 'package:app/src/modulos/cardapio/interactor/models/produto_model.dart';
import 'package:flutter/material.dart';

class CardapioProvedor extends ChangeNotifier {
  final CategoriaServiceImpl _categoriaServiceImpl = CategoriaServiceImpl();
  final ProdutoServiceImpl _produtoServiceImpl = ProdutoServiceImpl();

  List<CategoriaModel> categorias = [];
  List<ProdutoModel> produtos = [];

  void listarCategorias() async {
    final res = await _categoriaServiceImpl.listar();
    categorias = res;
    notifyListeners();
  }

  Future<void> listarProdutosPorCategoria(String category) async {
    final res = await _produtoServiceImpl.listarPorCategoria(category);
    if (res.isEmpty) return;

    produtos = res;
    notifyListeners();
  }

  Future<List<ProdutoModel>> listarProdutosPorNome(String pesquisa) async {
    return await _produtoServiceImpl.listarPorNome(pesquisa);
  }
}
