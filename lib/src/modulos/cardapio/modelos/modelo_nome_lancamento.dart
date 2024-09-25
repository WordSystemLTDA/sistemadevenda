// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloNomeLancamento {
  final String nome;
  final String valor;

  ModeloNomeLancamento({required this.nome, required this.valor});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nome': nome,
      'valor': valor,
    };
  }

  factory ModeloNomeLancamento.fromMap(Map<String, dynamic> map) {
    return ModeloNomeLancamento(
      nome: map['nome'] as String,
      valor: map['valor'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloNomeLancamento.fromJson(String source) => ModeloNomeLancamento.fromMap(json.decode(source) as Map<String, dynamic>);
}
