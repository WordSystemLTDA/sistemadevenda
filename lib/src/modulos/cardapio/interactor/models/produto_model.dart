import 'dart:convert';

class ProdutoModel {
  final String id;
  final String nome;
  final String tamanho;
  final String foto;
  final String descricao;
  final String valorVenda;

  ProdutoModel({
    required this.id,
    required this.nome,
    required this.tamanho,
    required this.foto,
    required this.descricao,
    required this.valorVenda,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'tamanho': tamanho,
      'foto': foto,
      'descricao': descricao,
      'valorVenda': valorVenda,
    };
  }

  factory ProdutoModel.fromMap(Map<String, dynamic> map) {
    return ProdutoModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      tamanho: map['tamanho'] as String,
      foto: map['foto'] as String,
      descricao: map['descricao'] as String,
      valorVenda: map['valorVenda'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ProdutoModel.fromJson(String source) => ProdutoModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
