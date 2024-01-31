import 'dart:convert';

class ItemComandaModelo {
  final String id;
  final String nome;
  final String foto;
  final double valor;
  final num quantidade;

  ItemComandaModelo({
    required this.id,
    required this.nome,
    required this.foto,
    required this.valor,
    required this.quantidade,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'foto': foto,
      'valor': valor,
      'quantidade': quantidade,
    };
  }

  factory ItemComandaModelo.fromMap(Map<String, dynamic> map) {
    return ItemComandaModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      foto: map['foto'] as String,
      valor: map['valor'] as double,
      quantidade: map['quantidade'] as num,
    );
  }

  String toJson() => json.encode(toMap());

  factory ItemComandaModelo.fromJson(String source) => ItemComandaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
