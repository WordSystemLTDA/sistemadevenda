// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class TamanhosModelo {
  final String id;
  final String nome;
  final String valor;
  final String foto;

  TamanhosModelo({
    required this.id,
    required this.nome,
    required this.valor,
    required this.foto,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'foto': foto,
    };
  }

  factory TamanhosModelo.fromMap(Map<String, dynamic> map) {
    return TamanhosModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] as String,
      foto: map['foto'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory TamanhosModelo.fromJson(String source) => TamanhosModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
