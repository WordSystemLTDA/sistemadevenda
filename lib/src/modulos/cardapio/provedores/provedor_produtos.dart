import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';

class ProvedorProdutos extends ChangeNotifier {
  final ServicoProduto _produtoService;

  ProvedorProdutos(this._produtoService);

  List<Modelowordprodutos> _produtos = [];
  List<Modelowordprodutos> get produtos => _produtos;
  set produtos(List<Modelowordprodutos> value) {
    _produtos = value;
    notifyListeners();
  }

  void resetarTudo() {
    produtos = [];
    notifyListeners();
  }

  Future<void> listarProdutosPorCategoria(String category) async {
    final res = await _produtoService.listarPorCategoria(category);
    if (res.isEmpty) return;

    produtos = res;
    notifyListeners();
  }

  Future<List<Modelowordprodutos>> listarProdutosPorNome(String pesquisa, String categoria, String idcliente) async {
    return await _produtoService.listarPorNome(pesquisa, categoria, idcliente);
  }
}
