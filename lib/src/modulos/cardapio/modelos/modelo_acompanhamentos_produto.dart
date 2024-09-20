// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modelowordacompanhamentosproduto {
  final String id;
  final String nome;
  final String valor;
  final String foto;
  bool estaSelecionado;
  bool excluir;

  Modelowordacompanhamentosproduto({
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

  factory Modelowordacompanhamentosproduto.fromMap(Map<String, dynamic> map) {
    return Modelowordacompanhamentosproduto(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] as String,
      foto: map['foto'] as String,
      estaSelecionado: map['estaSelecionado'] as bool,
      excluir: map['excluir'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordacompanhamentosproduto.fromJson(String source) => Modelowordacompanhamentosproduto.fromMap(json.decode(source) as Map<String, dynamic>);
}
