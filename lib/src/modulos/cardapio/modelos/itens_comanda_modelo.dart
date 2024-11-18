import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ItensModeloComandao {
  final List<ModeloProduto> listaComandosPedidos;
  final num quantidadeTotal;
  double precoTotal;

  ItensModeloComandao({
    required this.listaComandosPedidos,
    required this.quantidadeTotal,
    required this.precoTotal,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'listaComandosPedidos': listaComandosPedidos.map((x) => x.toMap()).toList(),
      'quantidadeTotal': quantidadeTotal,
      'precoTotal': precoTotal,
    };
  }

  factory ItensModeloComandao.fromMap(Map<String, dynamic> map) {
    return ItensModeloComandao(
      listaComandosPedidos: List<ModeloProduto>.from(
        (map['listaComandosPedidos'] as List<dynamic>).map<ModeloProduto>(
          (x) => ModeloProduto.fromMap(x as Map<String, dynamic>),
        ),
      ),
      quantidadeTotal: map['quantidadeTotal'] as num,
      precoTotal: map['precoTotal'] as double,
    );
  }

  String toJson() => json.encode(toMap());

  factory ItensModeloComandao.fromJson(String source) => ItensModeloComandao.fromMap(json.decode(source) as Map<String, dynamic>);
}
