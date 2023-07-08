import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first

class MesasModel {
  List<dynamic>? mesasOcupadas;
  List<dynamic>? mesasLivres;

  MesasModel({
    required this.mesasOcupadas,
    required this.mesasLivres,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mesasOcupadas': mesasOcupadas,
      'mesasLivres': mesasLivres,
    };
  }

  factory MesasModel.fromMap(Map<String, dynamic> map) {
    return MesasModel(
      mesasOcupadas: map['mesasOcupadas'] != null ? List<dynamic>.from((map['mesasOcupadas'] as List<dynamic>)) : null,
      mesasLivres: map['mesasLivres'] != null ? List<dynamic>.from((map['mesasLivres'] as List<dynamic>)) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesasModel.fromJson(String source) => MesasModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
