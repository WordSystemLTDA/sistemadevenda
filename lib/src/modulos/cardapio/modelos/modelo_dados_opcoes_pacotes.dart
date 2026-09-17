import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';

String _texto(Object? valor, [String padrao = '']) =>
    valor?.toString() ?? padrao;

bool? _boolOpcional(Object? valor) {
  if (valor == null) return null;
  if (valor is bool) return valor;
  final texto = valor.toString().toLowerCase();
  if (texto == 'true' || texto == '1' || texto == 'sim') return true;
  if (texto == 'false' || texto == '0' || texto == 'nao' || texto == 'não') {
    return false;
  }
  return null;
}

int? _inteiroOpcional(Object? valor) {
  if (valor is num) return valor.toInt();
  return int.tryParse((valor ?? '').toString());
}

Map<String, dynamic>? _mapa(Object? valor) {
  if (valor is Map) return Map<String, dynamic>.from(valor);
  if (valor is String && valor.trim().isNotEmpty) {
    try {
      final decodificado = json.decode(valor);
      if (decodificado is Map) {
        return Map<String, dynamic>.from(decodificado);
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

// ignore_for_file: public_member_api_docs, sort_constructors_first
class ModeloDadosOpcoesPacotes {
  final String id;
  final String nome;
  final String? codigo;
  final String? idProduto;
  final String imprimirCodigoProdutoPreparo;
  final String? valor;
  final String? valorOriginal;
  final String? foto;
  final String? idtamanhospizza;
  final String? quantimaximaselecao;
  final String? habilsepardelivery;
  final String? idCategoriaCardapio;
  final String? diaSemana;
  final MontagemIngredienteCardapio? montagemCardapio;
  bool? estaSelecionado;
  bool? excluir;
  int? quantidade;
  bool somenteMetadeBorda;

  ModeloDadosOpcoesPacotes({
    required this.id,
    required this.nome,
    this.codigo,
    this.idProduto,
    this.imprimirCodigoProdutoPreparo = 'Não',
    this.valor,
    this.valorOriginal,
    this.foto,
    this.idtamanhospizza,
    this.quantimaximaselecao,
    this.habilsepardelivery,
    this.idCategoriaCardapio,
    this.diaSemana,
    this.montagemCardapio,
    this.estaSelecionado,
    this.excluir,
    this.quantidade,
    this.somenteMetadeBorda = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'codigo': codigo,
      'idProduto': idProduto,
      'imprimirCodigoProdutoPreparo': imprimirCodigoProdutoPreparo,
      'valor': valor,
      if (valorOriginal != null) 'valorOriginal': valorOriginal,
      'foto': foto,
      'idtamanhospizza': idtamanhospizza,
      'quantimaximaselecao': quantimaximaselecao,
      'habilsepardelivery': habilsepardelivery,
      'idCategoriaCardapio': idCategoriaCardapio,
      'categoriaCardapio': idCategoriaCardapio,
      'id_categoria_cardapio': idCategoriaCardapio,
      'diaSemana': diaSemana,
      'dia_semana': diaSemana,
      if (montagemCardapio != null)
        'montagemCardapio': montagemCardapio!.toMap(),
      'estaSelecionado': estaSelecionado,
      'excluir': excluir,
      'quantidade': quantidade,
      if (somenteMetadeBorda) 'somenteMetadeBorda': somenteMetadeBorda,
    };
  }

  factory ModeloDadosOpcoesPacotes.fromMap(Map<String, dynamic> map) {
    final montagem = _mapa(map['montagemCardapio'] ??
        map['montagem_cardapio'] ??
        map['montagem_json']);
    return ModeloDadosOpcoesPacotes(
      id: _texto(map['id']),
      nome: _texto(map['nome']),
      codigo: map['codigo']?.toString(),
      idProduto: map['idProduto']?.toString() ?? map['id_produto']?.toString(),
      valor: map['valor']?.toString(),
      valorOriginal: map['valorOriginal']?.toString(),
      foto: map['foto']?.toString(),
      idtamanhospizza: map['idtamanhospizza']?.toString(),
      quantimaximaselecao: map['quantimaximaselecao']?.toString(),
      habilsepardelivery: map['habilsepardelivery']?.toString(),
      idCategoriaCardapio: map['idCategoriaCardapio']?.toString() ??
          map['categoriaCardapio']?.toString() ??
          map['id_categoria_cardapio']?.toString(),
      diaSemana: map['diaSemana']?.toString() ?? map['dia_semana']?.toString(),
      montagemCardapio: montagem == null
          ? null
          : MontagemIngredienteCardapio.fromMap(montagem),
      estaSelecionado: _boolOpcional(map['estaSelecionado']),
      excluir: _boolOpcional(map['excluir']),
      quantidade: _inteiroOpcional(map['quantidade']),
      somenteMetadeBorda: _boolOpcional(map['somenteMetadeBorda']) == true ||
          _boolOpcional(map['bordaSomenteMetade']) == true ||
          _boolOpcional(map['somente_metade_borda']) == true,
      imprimirCodigoProdutoPreparo: (map['imprimirCodigoProdutoPreparo'] ??
                  map['imprimir_codigo_produto_preparo'])
              ?.toString() ??
          'Não',
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDadosOpcoesPacotes.fromJson(String source) =>
      ModeloDadosOpcoesPacotes.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
