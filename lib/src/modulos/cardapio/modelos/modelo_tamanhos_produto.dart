// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modelowordtamanhosproduto {
  final String id;
  final String nome;
  final String valor;
  final String foto;
  bool estaSelecionado;
  bool excluir;

  Modelowordtamanhosproduto({
    required this.id,
    required this.nome,
    required this.valor,
    required this.foto,
    required this.estaSelecionado,
    required this.excluir,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'foto': foto,
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
    };
  }

  factory Modelowordtamanhosproduto.fromMap(Map<String, dynamic> map) {
    return Modelowordtamanhosproduto(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] as String,
      foto: map['foto'] as String,
      estaSelecionado: map['estaSelecionado'] as bool,
      excluir: map['excluir'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordtamanhosproduto.fromJson(String source) => Modelowordtamanhosproduto.fromMap(json.decode(source) as Map<String, dynamic>);
}
