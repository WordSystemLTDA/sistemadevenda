// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';

class ModeloCategoria {
  String id;
  String nomeCategoria;
  String quantidadeProdutos;
  List<ModeloTamanhosPizza>? tamanhosPizza;

  ModeloCategoria({
    required this.id,
    required this.nomeCategoria,
    required this.quantidadeProdutos,
    this.tamanhosPizza,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nomeCategoria': nomeCategoria,
      'quantidadeProdutos': quantidadeProdutos,
      'tamanhosPizza': tamanhosPizza?.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloCategoria.fromMap(Map<String, dynamic> map) {
    return ModeloCategoria(
      id: map['id'] as String,
      nomeCategoria: map['nomeCategoria'] as String,
      quantidadeProdutos: map['quantidadeProdutos'] as String,
      tamanhosPizza: map['tamanhosPizza'] != null
          ? List<ModeloTamanhosPizza>.from(
              (map['tamanhosPizza'] as List<dynamic>).map<ModeloTamanhosPizza?>(
                (x) => ModeloTamanhosPizza.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloCategoria.fromJson(String source) =>
      ModeloCategoria.fromMap(json.decode(source) as Map<String, dynamic>);
}
