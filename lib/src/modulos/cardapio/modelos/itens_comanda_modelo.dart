import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/carrinho_modelo.dart';

class ItensComandaModelo {
  final List<CarrinhoModelo> listaComandosPedidos;
  final num quantidadeTotal;
  double precoTotal;

  ItensComandaModelo({
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

  factory ItensComandaModelo.fromMap(Map<String, dynamic> map) {
    return ItensComandaModelo(
      listaComandosPedidos: List<CarrinhoModelo>.from(
        (map['listaComandosPedidos'] as List<dynamic>).map<CarrinhoModelo>(
          (x) => CarrinhoModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
      quantidadeTotal: map['quantidadeTotal'] as num,
      precoTotal: map['precoTotal'] as double,
    );
  }

  String toJson() => json.encode(toMap());

  factory ItensComandaModelo.fromJson(String source) => ItensComandaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
