import 'dart:convert';

class BancoPixModelo {
  final String id;
  final String nome;

  BancoPixModelo({
    required this.id,
    required this.nome,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
    };
  }

  factory BancoPixModelo.fromMap(Map<String, dynamic> map) {
    return BancoPixModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory BancoPixModelo.fromJson(String source) => BancoPixModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
