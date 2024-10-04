// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloConexao {
  final String tipoConexao;
  final String servidor;

  ModeloConexao({required this.tipoConexao, required this.servidor});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tipoConexao': tipoConexao,
      'servidor': servidor,
    };
  }

  factory ModeloConexao.fromMap(Map<String, dynamic> map) {
    return ModeloConexao(
      tipoConexao: map['tipoConexao'] as String,
      servidor: map['servidor'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloConexao.fromJson(String source) => ModeloConexao.fromMap(json.decode(source) as Map<String, dynamic>);
}
