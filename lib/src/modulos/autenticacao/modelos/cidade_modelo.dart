// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class CidadeModelo {
  final String id;
  final String nome;
  final String nomeUf;
  final String siglaUf;

  CidadeModelo({required this.id, required this.nome, required this.nomeUf, required this.siglaUf});

  factory CidadeModelo.fromJson(String source) => CidadeModelo.fromMap(json.decode(source) as Map<String, dynamic>);

  factory CidadeModelo.fromMap(Map<String, dynamic> map) {
    return CidadeModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      nomeUf: map['nomeUf'] as String,
      siglaUf: map['siglaUf'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'nomeUf': nomeUf,
      'siglaUf': siglaUf,
    };
  }
}
