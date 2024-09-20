import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class ModeloDadosOpcoesPacotes {
  final String id;
  final String nome;
  final String? valor;
  final String? foto;
  bool? estaSelecionado;
  bool? excluir;
  int? quantidade;

  ModeloDadosOpcoesPacotes({
    required this.id,
    required this.nome,
    this.valor,
    this.foto,
    this.estaSelecionado,
    this.excluir,
    this.quantidade,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'valor': valor,
      'foto': foto,
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
      'quantidade': quantidade,
    };
  }

  factory ModeloDadosOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    return ModeloDadosOpcoesPacotes(
      id: map['id'] as String,
      nome: map['nome'] as String,
      valor: map['valor'] != null ? map['valor'] as String : null,
      foto: map['foto'] != null ? map['foto'] as String : null,
      estaSelecionado: map['estaSelecionado'] != null ? map['estaSelecionado'] as bool : null,
      excluir: map['excluir'] != null ? map['excluir'] as bool : null,
      quantidade: map['quantidade'] != null ? map['quantidade'] as int : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDadosOpcoesPacotes.fromJson(String source) => ModeloDadosOpcoesPacotes.fromMap(json.decode(source) as Map<String, dynamic>);
}
