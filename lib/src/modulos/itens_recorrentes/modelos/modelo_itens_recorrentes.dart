import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ModeloItensRecorrentes {
  final String idComandaPedido;
  final List<Modelowordprodutos> produtos;

  ModeloItensRecorrentes({
    required this.idComandaPedido,
    required this.produtos,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'idComandaPedido': idComandaPedido,
      'produtos': produtos.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloItensRecorrentes.fromMap(Map<String, dynamic> map) {
    return ModeloItensRecorrentes(
      idComandaPedido: map['idComandaPedido'] as String,
      produtos: List<Modelowordprodutos>.from(
        (map['produtos'] as List<dynamic>).map<Modelowordprodutos>(
          (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloItensRecorrentes.fromJson(String source) => ModeloItensRecorrentes.fromMap(json.decode(source) as Map<String, dynamic>);
}
