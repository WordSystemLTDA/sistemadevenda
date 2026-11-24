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
  final int? limiteSelecao;
  final String? idCategoriaOpcoes;
  List<ModeloDadosOpcoesPacotes>? dados;
  List<ModeloOpcoesPacotes>? opcoesPacote;
  List<Modelowordprodutos>? produtos;

  ModeloOpcoesPacotes({
    required this.id,
    required this.titulo,
    required this.obrigatorio,
    this.tipo,
    this.limiteSelecao,
    this.idCategoriaOpcoes,
    this.opcoesPacote,
    required this.dados,
    this.produtos,
  });

  bool get ehCategoriaOpcoes => id == 13;
  int get limiteOpcoes => limiteSelecao ?? 1;

  String? validarOpcoes() {
    if (!ehCategoriaOpcoes) return null;
    final quantidade = dados?.length ?? 0;
    if (obrigatorio && quantidade == 0) return 'Selecione ao menos uma opção.';
    if (limiteOpcoes > 0 && quantidade > limiteOpcoes)
      return 'Selecione até $limiteOpcoes opções.';
    return null;
  }

  // Opera somente na lista final. O catálogo e seus padrões não são alterados.
  String? alternarOpcao(ModeloDadosOpcoesPacotes item) {
    final selecionadas = dados ??= [];
    final existe = selecionadas.any((dado) => dado.id == item.id);
    if (existe) {
      if (limiteOpcoes != 1 || !obrigatorio)
        selecionadas.removeWhere((dado) => dado.id == item.id);
    } else {
      if (limiteOpcoes == 1) {
        selecionadas.clear();
      } else if (limiteOpcoes > 0 && selecionadas.length >= limiteOpcoes) {
        return 'Selecione até $limiteOpcoes opções.';
      }
      selecionadas.add(ModeloDadosOpcoesPacotes.fromMap(
          {...item.toMap(), 'quantidade': 1, 'estaSelecionado': true}));
    }
    return null;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'titulo': titulo,
      'obrigatorio': obrigatorio,
      'tipo': tipo,
      if (limiteSelecao != null) 'limiteSelecao': limiteSelecao,
      if (idCategoriaOpcoes != null) 'idCategoriaOpcoes': idCategoriaOpcoes,
      'opcoesPacote': opcoesPacote?.map((x) => x.toMap()).toList(),
      'dados': dados?.map((x) => x.toMap()).toList(),
      'produtos': produtos?.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    final id = _inteiro(map['id']);
    final dados = _dados(map['dados']);
    return ModeloOpcoesPacotes(
      id: id,
      limiteSelecao:
          map['limiteSelecao'] == null ? null : _inteiro(map['limiteSelecao']),
      idCategoriaOpcoes: map['idCategoriaOpcoes']?.toString(),
      titulo: map['titulo']?.toString() ?? '',
      obrigatorio: _booleano(map['obrigatorio']),
      tipo: map['tipo'] == null ? null : _inteiro(map['tipo']),
      dados: const {1, 4, 5, 6, 7, 8, 11, 13}.contains(id)
          ? _ordenarVinculos(dados)
          : dados,
      opcoesPacote: _opcoes(map['opcoesPacote']),
      produtos: _produtos(map['produtos']),
    );
  }

  static List<ModeloDadosOpcoesPacotes>? _ordenarVinculos(
      List<ModeloDadosOpcoesPacotes>? dados) {
    if (dados == null) return null;
    final itens = dados.indexed.toList()
      ..sort((a, b) {
        final ordemA = a.$2.ordem > 0 ? a.$2.ordem : 0x7fffffff;
        final ordemB = b.$2.ordem > 0 ? b.$2.ordem : 0x7fffffff;
        final comparacao = ordemA.compareTo(ordemB);
        return comparacao != 0 ? comparacao : a.$1.compareTo(b.$1);
      });
    return itens.map((item) => item.$2).toList();
  }

  String toJson() => json.encode(toMap());

  factory ModeloOpcoesPacotes.fromJson(String source) =>
      ModeloOpcoesPacotes.fromMap(json.decode(source) as Map<String, dynamic>);
}
