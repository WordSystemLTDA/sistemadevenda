// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

int _inteiro(Object? valor, [int padrao = 0]) {
  if (valor is num) return valor.toInt();
  return int.tryParse((valor ?? '').toString()) ?? padrao;
}

bool _booleano(Object? valor, [bool padrao = false]) {
  if (valor is bool) return valor;
  final texto = (valor ?? '').toString().toLowerCase();
  if (texto == 'true' || texto == '1' || texto == 'sim') return true;
  if (texto == 'false' || texto == '0' || texto == 'nao' || texto == 'não') {
    return false;
  }
  return padrao;
}

List<ModeloDadosOpcoesPacotes>? _dados(Object? valor) {
  if (valor is! List) return null;
  final dados = <ModeloDadosOpcoesPacotes>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      dados.add(
          ModeloDadosOpcoesPacotes.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {
      continue;
    }
  }
  return dados;
}

List<ModeloOpcoesPacotes>? _opcoes(Object? valor) {
  if (valor is! List) return null;
  final opcoes = <ModeloOpcoesPacotes>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      opcoes.add(ModeloOpcoesPacotes.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {
      continue;
    }
  }
  return opcoes;
}

List<Modelowordprodutos>? _produtos(Object? valor) {
  if (valor is! List) return null;
  final produtos = <Modelowordprodutos>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      produtos.add(Modelowordprodutos.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {
      continue;
    }
  }
  return produtos;
}

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
      id: _inteiro(map['id']),
      titulo: map['titulo']?.toString() ?? '',
      obrigatorio: _booleano(map['obrigatorio']),
      tipo: map['tipo'] == null ? null : _inteiro(map['tipo']),
      dados: _dados(map['dados']),
      opcoesPacote: _opcoes(map['opcoesPacote']),
      produtos: _produtos(map['produtos']),
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloOpcoesPacotes.fromJson(String source) =>
      ModeloOpcoesPacotes.fromMap(json.decode(source) as Map<String, dynamic>);
}
