// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modelowordcortesiasproduto {
  final String id;
  final String nome;
  final String valor;
  final String quantimaximaselecao;
  final String foto;
  bool estaSelecionado;
  bool excluir;

  Modelowordcortesiasproduto({
    required this.id,
    required this.nome,
    required this.valor,
    required this.quantimaximaselecao,
    required this.foto,
    required this.estaSelecionado,
    required this.excluir,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'quantimaximaselecao': quantimaximaselecao,
      'foto': foto,
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
    };
  }

  factory Modelowordcortesiasproduto.fromMap(Map<String, dynamic> map) {
    return Modelowordcortesiasproduto(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] as String,
      quantimaximaselecao: map['quantimaximaselecao'] as String,
      foto: map['foto'] as String,
      estaSelecionado: map['estaSelecionado'] as bool,
      excluir: map['excluir'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordcortesiasproduto.fromJson(String source) =>
      Modelowordcortesiasproduto.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
