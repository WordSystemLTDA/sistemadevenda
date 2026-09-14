// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';

List<ModeloTamanhosPizza>? _tamanhosPizza(Object? valor) {
  if (valor is! List) return null;
  final tamanhos = <ModeloTamanhosPizza>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      tamanhos
          .add(ModeloTamanhosPizza.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {
      continue;
    }
  }
  return tamanhos;
}

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
      id: map['id']?.toString() ?? '',
      nomeCategoria: map['nomeCategoria']?.toString() ?? '',
      quantidadeProdutos: map['quantidadeProdutos']?.toString() ?? '0',
      tamanhosPizza: _tamanhosPizza(map['tamanhosPizza']),
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloCategoria.fromJson(String source) =>
      ModeloCategoria.fromMap(json.decode(source) as Map<String, dynamic>);
}
