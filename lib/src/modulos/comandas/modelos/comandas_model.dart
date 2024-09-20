import 'dart:convert';

import 'package:app/src/modulos/comandas/modelos/comanda_model.dart';

class ComandasModel {
  String titulo;
  List<ComandaModel>? comandas;

  ComandasModel({
    required this.titulo,
    required this.comandas,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'titulo': titulo,
      'comandas': comandas!.map((x) => x.toMap()).toList(),
    };
  }

  factory ComandasModel.fromMap(Map<String, dynamic> map) {
    return ComandasModel(
      titulo: map['titulo'] as String,
      comandas: map['comandas'] != null
          ? List<ComandaModel>.from(
              (map['comandas'] as List<dynamic>).map<ComandaModel?>(
                (x) => ComandaModel.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ComandasModel.fromJson(String source) => ComandasModel.fromMap(json.decode(source) as Map<String, dynamic>);
}
