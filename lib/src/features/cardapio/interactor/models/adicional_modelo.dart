import 'dart:convert';

class AdicionalModelo {
  final String id;
  final num quantidade;
  final double valorAdicional;
  final String nome;

  AdicionalModelo({
    required this.id,
    required this.quantidade,
    required this.valorAdicional,
    required this.nome,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'quantidade': quantidade,
      'valorAdicional': valorAdicional,
      'nome': nome,
    };
  }

  factory AdicionalModelo.fromMap(Map<String, dynamic> map) {
    return AdicionalModelo(
      id: map['id'] as String,
      quantidade: map['quantidade'] as num,
      valorAdicional: map['valorAdicional'] as double,
      nome: map['nome'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory AdicionalModelo.fromJson(String source) => AdicionalModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
