// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class CategoriaModel {
  String id;
  String nomeCategoria;

  CategoriaModel({
    required this.id,
    required this.nomeCategoria,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nomeCategoria': nomeCategoria,
    };
  }

  factory CategoriaModel.fromMap(Map<String, dynamic> map) {
    return CategoriaModel(
      id: map['id'] as String,
      nomeCategoria: map['nomeCategoria'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory CategoriaModel.fromJson(String source) => CategoriaModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
