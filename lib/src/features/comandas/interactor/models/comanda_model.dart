// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ComandaModel {
  String id;
  String nome;
  bool comandaOcupada;

  ComandaModel({
    required this.id,
    required this.nome,
    required this.comandaOcupada,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'comandaOcupada': comandaOcupada,
    };
  }

  factory ComandaModel.fromMap(Map<String, dynamic> map) {
    return ComandaModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      comandaOcupada: map['comandaOcupada'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory ComandaModel.fromJson(String source) => ComandaModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
