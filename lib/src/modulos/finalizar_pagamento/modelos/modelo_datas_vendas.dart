// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloDatasVendas {
  final String vendaDia1;
  final String vendaDia2;
  final String vendaDia3;
  final String vendaDia4;

  ModeloDatasVendas({required this.vendaDia1, required this.vendaDia2, required this.vendaDia3, required this.vendaDia4});

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'vendaDia1': vendaDia1,
      'vendaDia2': vendaDia2,
      'vendaDia3': vendaDia3,
      'vendaDia4': vendaDia4,
    };
  }

  factory ModeloDatasVendas.fromMap(Map<String, dynamic> map) {
    return ModeloDatasVendas(
      vendaDia1: map['vendaDia1'] as String,
      vendaDia2: map['vendaDia2'] as String,
      vendaDia3: map['vendaDia3'] as String,
      vendaDia4: map['vendaDia4'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDatasVendas.fromJson(String source) => ModeloDatasVendas.fromMap(json.decode(source) as Map<String, dynamic>);
}
