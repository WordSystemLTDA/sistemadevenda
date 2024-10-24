// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloTamanhosPizza {
  final String id;
  final String nomedotamanho;
  final String quantpedacos;
  final String saboreslimite;

  ModeloTamanhosPizza({required this.id, required this.nomedotamanho, required this.quantpedacos, required this.saboreslimite});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nomedotamanho': nomedotamanho,
      'quantpedacos': quantpedacos,
      'saboreslimite': saboreslimite,
    };
  }

  factory ModeloTamanhosPizza.fromMap(Map<String, dynamic> map) {
    return ModeloTamanhosPizza(
      id: map['id'] as String,
      nomedotamanho: map['nomedotamanho'] as String,
      quantpedacos: map['quantpedacos'] as String,
      saboreslimite: map['saboreslimite'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloTamanhosPizza.fromJson(String source) => ModeloTamanhosPizza.fromMap(json.decode(source) as Map<String, dynamic>);
}
