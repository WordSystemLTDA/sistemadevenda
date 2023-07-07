// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'mesa_model.dart';

class MesasModel {
  List<MesaModel>? mesasOcupadas;
  List<MesaModel>? mesasLivres;

  MesasModel({
    required this.mesasOcupadas,
    required this.mesasLivres,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'mesasOcupadas': mesasOcupadas?.map((x) => x.toMap()).toList(),
      'mesasLivres': mesasLivres?.map((x) => x.toMap()).toList(),
    };
  }

  factory MesasModel.fromMap(Map<String, dynamic> map) {
    return MesasModel(
      mesasOcupadas: map['mesasOcupadas'] != null
          ? List<MesaModel>.from(
              (map['mesasOcupadas'] as List<int>).map<MesaModel?>(
                (x) => MesaModel.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      mesasLivres: map['mesasLivres'] != null
          ? List<MesaModel>.from(
              (map['mesasLivres'] as List<int>).map<MesaModel?>(
                (x) => MesaModel.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesasModel.fromJson(String source) =>
      MesasModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
