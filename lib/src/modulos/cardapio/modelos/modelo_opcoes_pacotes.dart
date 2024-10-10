// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ModeloOpcoesPacotes {
  final int id;
  final String tipo;
  final String titulo;
  final bool obrigatorio;
  final List<ModeloDadosOpcoesPacotes>? dados;
  final List<ModeloProduto>? produtos;

  ModeloOpcoesPacotes({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.obrigatorio,
    required this.dados,
    this.produtos,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'tipo': tipo,
      'titulo': titulo,
      'obrigatorio': obrigatorio,
      'dados': dados?.map((x) => x.toMap()).toList(),
      'produtos': produtos?.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    return ModeloOpcoesPacotes(
      id: map['id'] as int,
      tipo: map['tipo'] as String,
      titulo: map['titulo'] as String,
      obrigatorio: map['obrigatorio'] as bool,
      dados: map['dados'] != null
          ? List<ModeloDadosOpcoesPacotes>.from(
              (map['dados'] as List<dynamic>).map<ModeloDadosOpcoesPacotes?>(
                (x) => ModeloDadosOpcoesPacotes.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      produtos: map['produtos'] != null
          ? List<ModeloProduto>.from(
              (map['produtos'] as List<dynamic>).map<ModeloProduto?>(
                (x) => ModeloProduto.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloOpcoesPacotes.fromJson(String source) => ModeloOpcoesPacotes.fromMap(json.decode(source) as Map<String, dynamic>);
}
