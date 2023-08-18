// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ProdutoModel {
  String id;
  String nome;
  String tamanho;
  String imagem;
  num valor;
  String descricao;

  ProdutoModel({
    required this.id,
    required this.nome,
    required this.tamanho,
    required this.imagem,
    required this.valor,
    required this.descricao,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'tamanho': tamanho,
      'imagem': imagem,
      'valor': valor,
      'descricao': descricao,
    };
  }

  factory ProdutoModel.fromMap(Map<String, dynamic> map) {
    return ProdutoModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      tamanho: map['tamanho'] as String,
      imagem: map['imagem'] as String,
      valor: map['valor'] as num,
      descricao: map['descricao'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ProdutoModel.fromJson(String source) => ProdutoModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
