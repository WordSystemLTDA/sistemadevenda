// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modelolistafinanceirovenda {
  final String descricaoMov;
  final String documentoMov;
  final String entradaMov;
  final String vencimentoMovF;
  final String valorMovF;
  final String statusMov;

  Modelolistafinanceirovenda({
    required this.descricaoMov,
    required this.documentoMov,
    required this.entradaMov,
    required this.vencimentoMovF,
    required this.valorMovF,
    required this.statusMov,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'descricaoMov': descricaoMov,
      'documentoMov': documentoMov,
      'entradaMov': entradaMov,
      'vencimentoMovF': vencimentoMovF,
      'valorMovF': valorMovF,
      'statusMov': statusMov,
    };
  }

  factory Modelolistafinanceirovenda.fromMap(Map<String, dynamic> map) {
    return Modelolistafinanceirovenda(
      descricaoMov: map['descricaoMov'] as String,
      documentoMov: map['documentoMov'] as String,
      entradaMov: map['entradaMov'] as String,
      vencimentoMovF: map['vencimentoMovF'] as String,
      valorMovF: map['valorMovF'] as String,
      statusMov: map['statusMov'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelolistafinanceirovenda.fromJson(String source) => Modelolistafinanceirovenda.fromMap(json.decode(source) as Map<String, dynamic>);
}
