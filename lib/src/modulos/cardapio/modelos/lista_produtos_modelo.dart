import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/produto_model.dart';

class ListaProdutosModelo {
  final String categoria;
  final List<ProdutoModel> listaProdutos;

  ListaProdutosModelo({
    required this.categoria,
    required this.listaProdutos,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'categoria': categoria,
      'listaProdutos': listaProdutos.map((x) => x.toMap()).toList(),
    };
  }

  factory ListaProdutosModelo.fromMap(Map<String, dynamic> map) {
    return ListaProdutosModelo(
      categoria: map['categoria'] as String,
      listaProdutos: List<ProdutoModel>.from(
        (map['listaProdutos'] as List<ProdutoModel>).map<ProdutoModel>(
          (x) => ProdutoModel.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ListaProdutosModelo.fromJson(String source) => ListaProdutosModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
