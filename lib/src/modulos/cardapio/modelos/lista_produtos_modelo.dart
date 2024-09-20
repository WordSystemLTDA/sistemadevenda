import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ListaProdutosModelo {
  final String categoria;
  final List<ModeloProduto> listaProdutos;

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
      listaProdutos: List<ModeloProduto>.from(
        (map['listaProdutos'] as List<ModeloProduto>).map<ModeloProduto>(
          (x) => ModeloProduto.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ListaProdutosModelo.fromJson(String source) => ListaProdutosModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
