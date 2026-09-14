// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloDescontoProduto {
  final String tipodedesconto;
  final String valordedesconto;
  final String valorretirado;
  final String datadeterminopromocao;
  final String ativo;

  ModeloDescontoProduto({
    required this.tipodedesconto,
    required this.valordedesconto,
    required this.valorretirado,
    required this.datadeterminopromocao,
    required this.ativo,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tipodedesconto': tipodedesconto,
      'valordedesconto': valordedesconto,
      'valorretirado': valorretirado,
      'datadeterminopromocao': datadeterminopromocao,
      'ativo': ativo,
    };
  }

  factory ModeloDescontoProduto.fromMap(Map<String, dynamic> map) {
    return ModeloDescontoProduto(
      tipodedesconto: map['tipodedesconto']?.toString() ?? '',
      valordedesconto: map['valordedesconto']?.toString() ?? '0',
      valorretirado: map['valorretirado']?.toString() ?? '0',
      datadeterminopromocao: map['datadeterminopromocao']?.toString() ?? '',
      ativo: map['ativo']?.toString() ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDescontoProduto.fromJson(String source) =>
      ModeloDescontoProduto.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
