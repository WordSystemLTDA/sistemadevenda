// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class AcompanhamentosModelo {
  final String id;
  final String nome;
  final String valor;
  final String foto;
  bool estaSelecionado;

  AcompanhamentosModelo({
    required this.id,
    required this.nome,
    required this.valor,
    required this.foto,
    required this.estaSelecionado,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'foto': foto,
      'estaSelecionado': estaSelecionado,
    };
  }

  factory AcompanhamentosModelo.fromMap(Map<String, dynamic> map) {
    return AcompanhamentosModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] as String,
      foto: map['foto'] as String,
      estaSelecionado: map['estaSelecionado'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory AcompanhamentosModelo.fromJson(String source) => AcompanhamentosModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
