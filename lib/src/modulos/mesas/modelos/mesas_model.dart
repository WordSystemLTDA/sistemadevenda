import 'dart:convert';

import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';

class MesasModel {
  String titulo;
  List<MesaModelo>? mesas;

  MesasModel({
    required this.titulo,
    required this.mesas,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'titulo': titulo,
      'mesas': mesas!.map((x) => x.toMap()).toList(),
    };
  }

  factory MesasModel.fromMap(Map<String, dynamic> map) {
    return MesasModel(
      titulo: map['titulo'] as String,
      mesas: map['mesas'] != null
          ? List<MesaModelo>.from(
              (map['mesas'] as List<dynamic>).map<MesaModelo?>(
                (x) => MesaModelo.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesasModel.fromJson(String source) => MesasModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
