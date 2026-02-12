// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modelowordingredientesproduto {
  final String id;
  final String nome;
  final String quantidade;

  Modelowordingredientesproduto({
    required this.id,
    required this.nome,
    required this.quantidade,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'quantidade': quantidade,
    };
  }

  factory Modelowordingredientesproduto.fromMap(Map<String, dynamic> map) {
    return Modelowordingredientesproduto(
      id: map['id'] as String,
      nome: map['nome'] as String,
      quantidade: map['quantidade'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordingredientesproduto.fromJson(String source) =>
      Modelowordingredientesproduto.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
