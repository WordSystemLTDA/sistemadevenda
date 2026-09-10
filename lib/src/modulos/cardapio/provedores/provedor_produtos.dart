import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:flutter/material.dart';

class ProvedorProdutos extends ChangeNotifier {
  final ServicoProduto _produtoService;

  ProvedorProdutos(this._produtoService);

  Map<String, int> paginas = {};
  static const int _itensPorPagina = 15;
  int _requisicao = 0;
  bool carregando = false;
  bool carregandoMais = false;
  bool temMais = true;
  bool erroAoCarregarMais = false;
  String? erro;
  String _pesquisa = '';
  final Map<String, Modelowordprodutos> _produtosCompletosPorId = {};
  List<Modelowordprodutos> _produtos = [];
  List<Modelowordprodutos> get produtos => _produtos;
  set produtos(List<Modelowordprodutos> value) {
    _produtos = value;
    notifyListeners();
  }

  void resetarTudo() {
    _requisicao++;
    paginas.clear();
    _produtosCompletosPorId.clear();
    _produtos = [];
    carregando = false;
    carregandoMais = false;
    temMais = true;
    erro = null;
    _pesquisa = '';
    notifyListeners();
  }

  void prepararPesquisa(String pesquisa) {
    // Invalida a resposta anterior ainda durante a digitacao/debounce.
    _requisicao++;
    _pesquisa = pesquisa.trim();
    carregando = true;
    carregandoMais = false;
    erro = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _requisicao++;
    super.dispose();
  }

  Future<void> listarProdutosPorCategoria(String category,
      {bool carregarMais = false}) async {
    if (carregarMais &&
        (carregando || carregandoMais || !temMais || _pesquisa.isNotEmpty)) {
      return;
    }
    final requisicao = ++_requisicao;
    final pagina = carregarMais ? (paginas[category] ?? 1) + 1 : 1;
    _pesquisa = '';
    carregando = !carregarMais;
    carregandoMais = carregarMais;
    erro = null;
    erroAoCarregarMais = false;
    notifyListeners();
    try {
      final res = await _produtoService.listarPorCategoria(category, pagina);
      if (requisicao != _requisicao) return;
      _guardarProdutosCompletos(res);
      final ids = carregarMais ? produtos.map((p) => p.id).toSet() : <String>{};
      final novos = res.where((p) => ids.add(p.id)).toList();
      _produtos = carregarMais ? [...produtos, ...novos] : novos;
      paginas[category] = pagina;
      temMais = res.length >= _itensPorPagina && novos.isNotEmpty;
    } catch (_) {
      if (requisicao != _requisicao) return;
      erro = 'Não foi possível carregar os produtos.';
      erroAoCarregarMais = carregarMais;
    } finally {
      if (requisicao == _requisicao) {
        carregando = false;
        carregandoMais = false;
        notifyListeners();
      }
    }
  }

  Future<void> listarProdutosPorNome(
      String pesquisa, String categoria, String idcliente) async {
    final requisicao = ++_requisicao;
    _pesquisa = pesquisa.trim();
    carregando = true;
    carregandoMais = false;
    erro = null;
    erroAoCarregarMais = false;
    notifyListeners();
    try {
      final res =
          await _produtoService.listarPorNome(_pesquisa, categoria, idcliente);
      if (requisicao != _requisicao) return;
      var itens = res.map(_completarProdutoPesquisado).toList();
      await _buscarProdutosCompletosParaPesquisa(itens, requisicao);
      if (requisicao != _requisicao) return;
      itens = itens.map(_completarProdutoPesquisado).toList();
      _produtos = itens;
      paginas[categoria] = 1;
      temMais = false;
    } catch (_) {
      if (requisicao != _requisicao) return;
      erro = 'Não foi possível pesquisar os produtos.';
    } finally {
      if (requisicao == _requisicao) {
        carregando = false;
        notifyListeners();
      }
    }
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
      List<Modelowordprodutos> itens, int requisicao) async {
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
        if (requisicao != _requisicao) return;
        final res = await _produtoService.listarPorCategoria(entry.key, pagina);
        if (requisicao != _requisicao) return;
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
