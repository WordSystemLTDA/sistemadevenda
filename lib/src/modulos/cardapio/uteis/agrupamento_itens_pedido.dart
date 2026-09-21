import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GrupoItensPedido {
  final Modelowordprodutos produto;
  final List<Modelowordprodutos> itensOriginais;

  const GrupoItensPedido({
    required this.produto,
    required this.itensOriginais,
  });

  bool get possuiMaisDeUmLancamento => itensOriginais.length > 1;
}

List<GrupoItensPedido> organizarItensPedido(
  List<Modelowordprodutos> produtos, {
  required bool agrupar,
}) {
  if (!agrupar) {
    return produtos
        .map((produto) => GrupoItensPedido(
              produto: produto,
              itensOriginais: [produto],
            ))
        .toList();
  }

  final grupos = <String, List<Modelowordprodutos>>{};
  for (final produto in produtos) {
    grupos.putIfAbsent(_chaveAgrupamento(produto), () => []).add(produto);
  }

  return grupos.values.map((itens) {
    if (itens.length == 1) {
      return GrupoItensPedido(produto: itens.first, itensOriginais: itens);
    }

    final produtoAgrupado = Modelowordprodutos.fromMap(itens.first.toMap());
    produtoAgrupado.quantidade = itens.fold<double>(
      0,
      (total, item) => total + (item.quantidade ?? 1),
    );
    return GrupoItensPedido(
      produto: produtoAgrupado,
      itensOriginais: List.unmodifiable(itens),
    );
  }).toList();
}

String _chaveAgrupamento(Modelowordprodutos produto) {
  return jsonEncode(<String, dynamic>{
    'id': produto.id,
    'codigo': produto.codigo,
    'nome': produto.nome,
    'valorVenda': produto.valorVenda,
    'tamanho': produto.tamanho,
    'observacao': produto.observacao?.trim() ?? '',
    'ingredientes': produto.ingredientes.map((item) => item.toMap()).toList(),
    'opcoes':
        produto.opcoesPacotesListaFinal?.map((opcao) => opcao.toMap()).toList(),
    'desconto': produto.descontoProduto?.toMap(),
  });
}

class PreferenciaAgrupamentoItensPedido {
  static const chave = 'detalhes_pedido_agrupar_itens_iguais';

  Future<bool> carregar() async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.getBool(chave) ?? false;
  }

  Future<bool> salvar(bool agrupar) async {
    final preferencias = await SharedPreferences.getInstance();
    return preferencias.setBool(chave, agrupar);
  }
}
