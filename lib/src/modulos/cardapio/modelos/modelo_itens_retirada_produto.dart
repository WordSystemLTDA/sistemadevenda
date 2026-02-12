// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modeloworditensretiradaproduto {
  final String id;
  final String nome;
  final String foto;
  bool estaSelecionado;
  bool excluir;

  Modeloworditensretiradaproduto({
    required this.id,
    required this.nome,
    required this.foto,
    required this.estaSelecionado,
    required this.excluir,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'foto': foto,
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
    };
  }

  factory Modeloworditensretiradaproduto.fromMap(Map<String, dynamic> map) {
    return Modeloworditensretiradaproduto(
      id: map['id'] as String,
      nome: map['nome'] as String,
      foto: map['foto'] as String,
      estaSelecionado: map['estaSelecionado'] as bool,
      excluir: map['excluir'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modeloworditensretiradaproduto.fromJson(String source) =>
      Modeloworditensretiradaproduto.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
