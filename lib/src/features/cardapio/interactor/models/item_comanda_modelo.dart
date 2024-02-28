import 'dart:convert';

import 'package:app/src/features/cardapio/interactor/models/adicional_modelo.dart';

class ItemComandaModelo {
  final String id;
  final String nome;
  final String foto;
  final double valor;
  num quantidade;
  final List<AdicionalModelo> listaAdicionais;

  ItemComandaModelo({
    required this.id,
    required this.nome,
    required this.foto,
    required this.valor,
    required this.quantidade,
    required this.listaAdicionais,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'foto': foto,
      'valor': valor,
      'quantidade': quantidade,
      'listaAdicionais': listaAdicionais.map((x) => x.toMap()).toList(),
    };
  }

  factory ItemComandaModelo.fromMap(Map<String, dynamic> map) {
    return ItemComandaModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      foto: map['foto'] as String,
      valor: map['valor'] as double,
      quantidade: map['quantidade'] as num,
      listaAdicionais: List<AdicionalModelo>.from(
        (map['listaAdicionais'] as List<int>).map<AdicionalModelo>(
          (x) => AdicionalModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ItemComandaModelo.fromJson(String source) => ItemComandaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
