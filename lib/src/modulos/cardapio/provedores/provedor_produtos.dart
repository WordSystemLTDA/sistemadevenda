import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';

class ProvedorProdutos extends ChangeNotifier {
  final ServicoProduto _produtoService;

  ProvedorProdutos(this._produtoService);

  Map<String, int> paginas = {};
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

  Future<void> listarProdutosPorCategoria(String category, {bool carregarMais = false}) async {
    if (paginas[category] == null) {
      paginas[category] = 1;
    }

    final res = await _produtoService.listarPorCategoria(category, paginas[category] ?? 1);
    if (res.isEmpty) return;

    if (carregarMais) {
      produtos = [...produtos, ...res];
    } else {
      produtos = res;
    }
    notifyListeners();
  }

  Future<void> listarProdutosPorNome(String pesquisa, String categoria, String idcliente) async {
    paginas[categoria] = 1;
    final res = await _produtoService.listarPorNome(pesquisa, categoria, idcliente);

    produtos = res;
    notifyListeners();
  }
}
