import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ListaProdutosModelo {
  final String categoria;
  final List<Modelowordprodutos> listaProdutos;

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
      listaProdutos: List<Modelowordprodutos>.from(
        (map['listaProdutos'] as List<Modelowordprodutos>).map<Modelowordprodutos>(
          (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ListaProdutosModelo.fromJson(String source) => ListaProdutosModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
