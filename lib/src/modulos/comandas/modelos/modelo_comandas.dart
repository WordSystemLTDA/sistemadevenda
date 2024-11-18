import 'dart:convert';

import 'package:app/src/modulos/comandas/modelos/modelo_comanda.dart';

class ModeloComandas {
  String titulo;
  List<ModeloComanda>? comandas;

  ModeloComandas({
    required this.titulo,
    required this.comandas,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'titulo': titulo,
      'comandas': comandas!.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloComandas.fromMap(Map<String, dynamic> map) {
    return ModeloComandas(
      titulo: map['titulo'] as String,
      comandas: map['comandas'] != null
          ? List<ModeloComanda>.from(
              (map['comandas'] as List<dynamic>).map<ModeloComanda?>(
                (x) => ModeloComanda.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloComandas.fromJson(String source) => ModeloComandas.fromMap(json.decode(source) as Map<String, dynamic>);
}
