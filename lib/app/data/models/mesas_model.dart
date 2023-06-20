// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'mesa_model.dart';

class MesasModel {
  List<MesaModel> mesasOcupadas;
  List<MesaModel> mesasLivres;
  MesasModel({
    required this.mesasOcupadas,
    required this.mesasLivres,
  });

  MesasModel copyWith({
    List<MesaModel>? mesasOcupadas,
    List<MesaModel>? mesasLivres,
  }) {
    return MesasModel(
      mesasOcupadas: mesasOcupadas ?? this.mesasOcupadas,
      mesasLivres: mesasLivres ?? this.mesasLivres,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mesasOcupadas': mesasOcupadas.map((x) => x.toMap()).toList(),
      'mesasLivres': mesasLivres.map((x) => x.toMap()).toList(),
    };
  }

  factory MesasModel.fromMap(Map<String, dynamic> map) {
    return MesasModel(
      mesasOcupadas: List<MesaModel>.from(
        (map['mesasOcupadas'] as List<int>).map<MesaModel>(
          (x) => MesaModel.fromMap(x as Map<String, dynamic>),
        ),
      ),
      mesasLivres: List<MesaModel>.from(
        (map['mesasLivres'] as List<int>).map<MesaModel>(
          (x) => MesaModel.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory MesasModel.fromJson(String source) => MesasModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'MesasModel(mesasOcupadas: $mesasOcupadas, mesasLivres: $mesasLivres)';

  @override
  bool operator ==(covariant MesasModel other) {
    if (identical(this, other)) return true;

    return listEquals(other.mesasOcupadas, mesasOcupadas) && listEquals(other.mesasLivres, mesasLivres);
  }

  @override
  int get hashCode => mesasOcupadas.hashCode ^ mesasLivres.hashCode;
}
