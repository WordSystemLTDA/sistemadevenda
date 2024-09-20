// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class AdicionaisModelo {
  final String id;
  final String nome;
  final String valor;
  final String foto;
  bool estaSelecionado;
  int quantidade;

  AdicionaisModelo({
    required this.id,
    required this.nome,
    required this.valor,
    required this.foto,
    required this.quantidade,
    required this.estaSelecionado,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'foto': foto,
      'quantidade': quantidade,
      'estaSelecionado': estaSelecionado,
    };
  }

  factory AdicionaisModelo.fromMap(Map<String, dynamic> map) {
    return AdicionaisModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] as String,
      foto: map['foto'] as String,
      quantidade: map['quantidade'] as int,
      estaSelecionado: map['estaSelecionado'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory AdicionaisModelo.fromJson(String source) => AdicionaisModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
