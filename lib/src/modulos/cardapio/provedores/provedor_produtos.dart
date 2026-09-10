import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';

class ProvedorProdutos extends ChangeNotifier {
  final ServicoProduto _produtoService;

  ProvedorProdutos(this._produtoService);

  Map<String, int> paginas = {};
  final Map<String, Modelowordprodutos> _produtosCompletosPorId = {};
  List<Modelowordprodutos> _produtos = [];
  List<Modelowordprodutos> get produtos => _produtos;
  set produtos(List<Modelowordprodutos> value) {
    _produtos = value;
    notifyListeners();
  }

  void resetarTudo() {
    _produtosCompletosPorId.clear();
    produtos = [];
    notifyListeners();
  }

  Future<void> listarProdutosPorCategoria(String category,
      {bool carregarMais = false}) async {
    if (paginas[category] == null) {
      paginas[category] = 1;
    }

    final res = await _produtoService.listarPorCategoria(
        category, paginas[category] ?? 1);
    if (res.isEmpty) return;
    _guardarProdutosCompletos(res);

    if (carregarMais) {
      produtos = [...produtos, ...res];
    } else {
      produtos = res;
    }
    notifyListeners();
  }

  Future<void> listarProdutosPorNome(
      String pesquisa, String categoria, String idcliente) async {
    paginas[categoria] = 1;
    final res =
        await _produtoService.listarPorNome(pesquisa, categoria, idcliente);

    var itens = res.map(_completarProdutoPesquisado).toList();
    await _buscarProdutosCompletosParaPesquisa(itens);
    itens = itens.map(_completarProdutoPesquisado).toList();

    produtos = itens;
    notifyListeners();
  }

  void _guardarProdutosCompletos(List<Modelowordprodutos> itens) {
    for (final produto in itens) {
      _produtosCompletosPorId[produto.id] = produto;
    }
  }

  Modelowordprodutos _completarProdutoPesquisado(Modelowordprodutos produto) {
    final produtoCompleto = _produtosCompletosPorId[produto.id];
    if (produtoCompleto == null) {
      return produto;
    }

    if ((produto.tamanhosPizza?.isEmpty ?? true) &&
        (produtoCompleto.tamanhosPizza?.isNotEmpty ?? false)) {
      produto.tamanhosPizza = produtoCompleto.tamanhosPizza;
    }

    if ((produto.opcoesPacotes?.isEmpty ?? true) &&
        (produtoCompleto.opcoesPacotes?.isNotEmpty ?? false)) {
      produto.opcoesPacotes = produtoCompleto.opcoesPacotes;
    }

    return produto;
  }

  Future<void> _buscarProdutosCompletosParaPesquisa(
      List<Modelowordprodutos> itens) async {
    final pendentesPorCategoria = <String, Set<String>>{};

    for (final produto in itens) {
      if (!_deveBuscarProdutoCompleto(produto)) {
        continue;
      }

      pendentesPorCategoria
          .putIfAbsent(produto.categoria, () => <String>{})
          .add(produto.id);
    }

    for (final entry in pendentesPorCategoria.entries) {
      var pagina = 1;
      final pendentes = entry.value;

      while (pendentes.isNotEmpty && pagina <= 20) {
        final res = await _produtoService.listarPorCategoria(entry.key, pagina);
        if (res.isEmpty) {
          break;
        }

        _guardarProdutosCompletos(res);
        pendentes.removeWhere(_produtosCompletosPorId.containsKey);
        pagina++;
      }
    }
  }

  bool _deveBuscarProdutoCompleto(Modelowordprodutos produto) {
    if (_produtosCompletosPorId.containsKey(produto.id)) {
      return false;
    }

    if (produto.categoria.isEmpty || produto.categoria == '0') {
      return false;
    }

    final valorVenda = double.tryParse(produto.valorVenda.replaceAll(',', '.'));
    return valorVenda == 0 && (produto.tamanhosPizza?.isEmpty ?? true);
  }
}
