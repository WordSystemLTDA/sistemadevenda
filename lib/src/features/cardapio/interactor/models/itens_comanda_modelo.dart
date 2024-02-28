import 'dart:convert';

import 'package:app/src/features/cardapio/interactor/models/item_Comanda_modelo.dart';

class ItensComandaModelo {
  final List<ItemComandaModelo> listaComandosPedidos;
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
      listaComandosPedidos: List<ItemComandaModelo>.from(
        (map['listaComandosPedidos'] as List<num>).map<ItemComandaModelo>(
          (x) => ItemComandaModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
      quantidadeTotal: map['quantidadeTotal'] as num,
      precoTotal: map['precoTotal'] as double,
    );
  }

  String toJson() => json.encode(toMap());

  factory ItensComandaModelo.fromJson(String source) => ItensComandaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
