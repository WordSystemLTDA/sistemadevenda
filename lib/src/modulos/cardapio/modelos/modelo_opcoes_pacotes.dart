// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';

class ModeloOpcoesPacotes {
  final int id;
  final String titulo;
  final bool obrigatorio;
  final List<ModeloDadosOpcoesPacotes> dados;

  ModeloOpcoesPacotes({
    required this.id,
    required this.titulo,
    required this.obrigatorio,
    required this.dados,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'obrigatorio': obrigatorio,
      'dados': dados.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    return ModeloOpcoesPacotes(
      id: map['id'] as int,
      titulo: map['titulo'] as String,
      obrigatorio: map['obrigatorio'] as bool,
      dados: List<ModeloDadosOpcoesPacotes>.from(
        (map['dados'] as List<dynamic>).map<ModeloDadosOpcoesPacotes>(
          (x) => ModeloDadosOpcoesPacotes.fromMap(x as Map<String, dynamic>),
        ),
      ),
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloOpcoesPacotes.fromJson(String source) => ModeloOpcoesPacotes.fromMap(json.decode(source) as Map<String, dynamic>);
}
