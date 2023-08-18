import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first

class ComandasModel {
  List<dynamic>? comandasOcupadas;
  List<dynamic>? comandasLivres;

  ComandasModel({
    required this.comandasOcupadas,
    required this.comandasLivres,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'comandasOcupadas': comandasOcupadas,
      'comandasLivres': comandasLivres,
    };
  }

  factory ComandasModel.fromMap(Map<String, dynamic> map) {
    return ComandasModel(
      comandasOcupadas: map['comandasOcupadas'] != null ? List<dynamic>.from((map['comandasOcupadas'] as List<dynamic>)) : null,
      comandasLivres: map['comandasLivres'] != null ? List<dynamic>.from((map['comandasLivres'] as List<dynamic>)) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ComandasModel.fromJson(String source) => ComandasModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
