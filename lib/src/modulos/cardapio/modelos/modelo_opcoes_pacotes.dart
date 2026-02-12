// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

class ModeloOpcoesPacotes {
  final int id;
  final String titulo;
  final bool obrigatorio;
  final int? tipo;
  List<ModeloDadosOpcoesPacotes>? dados;
  List<ModeloOpcoesPacotes>? opcoesPacote;
  List<Modelowordprodutos>? produtos;

  ModeloOpcoesPacotes({
    required this.id,
    required this.titulo,
    required this.obrigatorio,
    this.tipo,
    this.opcoesPacote,
    required this.dados,
    this.produtos,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'obrigatorio': obrigatorio,
      'tipo': tipo,
      'opcoesPacote': opcoesPacote?.map((x) => x.toMap()).toList(),
      'dados': dados?.map((x) => x.toMap()).toList(),
      'produtos': produtos?.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    return ModeloOpcoesPacotes(
      id: map['id'] as int,
      titulo: map['titulo'] as String,
      obrigatorio: map['obrigatorio'] as bool,
      tipo: map['tipo'] != null ? map['tipo'] as int : null,
      dados: map['dados'] != null
          ? List<ModeloDadosOpcoesPacotes>.from(
              (map['dados'] as List<dynamic>).map<ModeloDadosOpcoesPacotes?>(
                (x) =>
                    ModeloDadosOpcoesPacotes.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      opcoesPacote: map['opcoesPacote'] != null
          ? List<ModeloOpcoesPacotes>.from(
              (map['opcoesPacote'] as List<dynamic>).map<ModeloOpcoesPacotes?>(
                (x) => ModeloOpcoesPacotes.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      produtos: map['produtos'] != null
          ? List<Modelowordprodutos>.from(
              (map['produtos'] as List<dynamic>).map<Modelowordprodutos?>(
                (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloOpcoesPacotes.fromJson(String source) =>
      ModeloOpcoesPacotes.fromMap(json.decode(source) as Map<String, dynamic>);
}
