// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_desconto_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_ingredientes_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:flutter/material.dart';

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

double? _decimalOpcional(Object? valor) {
  if (valor is num) return valor.toDouble();
  return double.tryParse((valor ?? '').toString().replaceAll(',', '.'));
}

Map<String, dynamic>? _mapa(Object? valor) =>
    valor is Map ? Map<String, dynamic>.from(valor) : null;

List<Modelowordingredientesproduto> _ingredientes(Object? valor) {
  if (valor is! List) return <Modelowordingredientesproduto>[];
  final ingredientes = <Modelowordingredientesproduto>[];
  for (final item in valor) {
    final mapa = _mapa(item);
    if (mapa == null) continue;
    try {
      ingredientes.add(Modelowordingredientesproduto.fromMap(mapa));
    } catch (_) {
      continue;
    }
  }
  return ingredientes;
}

List<ModeloOpcoesPacotes>? _opcoes(Object? valor) {
  if (valor is! List) return null;
  final opcoes = <ModeloOpcoesPacotes>[];
  for (final item in valor) {
    final mapa = _mapa(item);
    if (mapa == null) continue;
    try {
      opcoes.add(ModeloOpcoesPacotes.fromMap(mapa));
    } catch (_) {
      continue;
    }
  }
  return opcoes;
}

List<Modelowordtamanhosproduto>? _tamanhosPizza(Object? valor) {
  if (valor is! List) return null;
  final tamanhos = <Modelowordtamanhosproduto>[];
  for (final item in valor) {
    final mapa = _mapa(item);
    if (mapa == null) continue;
    try {
      tamanhos.add(Modelowordtamanhosproduto.fromMap(mapa));
    } catch (_) {
      continue;
    }
  }
  return tamanhos;
}

class Modelowordprodutos {
  String id;
  String? hashprodutos;
  String? iditensvenda;
  String? versaoEdicao;
  String nome;
  String codigo;
  String imprimirCodigoProdutoPreparo;
  String estoque;
  String tamanho;
  String foto;
  String ativo;
  String descricao;
  String valorVenda;
  String categoria;
  String nomeCategoria;
  String? dataLancado;
  String? ativarEdQtd;
  String? ativarCustoDeProducao;
  // bool excluir;
  bool? novo;
  ModeloDestinoImpressao? destinoDeImpressao;
  String habilTipo;
  String? habilItensRetirada;
  String? ativoLoja;
  List<Modelowordtamanhosproduto>? tamanhosPizza;
  // List<Modelowordcortesiasproduto> cortesias;
  // List<Modelowordprodutos> kits;
  // List<Modelowordadicionaisproduto> adicionais;
  // List<Modelowordacompanhamentosproduto> acompanhamentos;
  // List<Modelowordtamanhosproduto> tamanhos;
  // List<Modeloworditensretiradaproduto> itensRetiradas;
  List<Modelowordingredientesproduto> ingredientes;
  double? quantidade;
  int? quantidadePessoa;
  int? tamanhoLista;
  String? valorTotalVendas;
  String? observacao;
  TextEditingController? quantidadeController;
  Widget? acoes;
  String? valorRestoDivisao;
  List<ModeloOpcoesPacotes>? opcoesPacotes;
  List<ModeloOpcoesPacotes>? opcoesPacotesListaFinal;
  ModeloDescontoProduto? descontoProduto;
  String? habilsepardelivery;
  String? idCategoriaCardapio;
  int? limiteSaboresBorda;
  bool conferidoNoCarrinho;

  Modelowordprodutos({
    required this.id,
    this.iditensvenda,
    this.versaoEdicao,
    this.hashprodutos,
    required this.nome,
    required this.codigo,
    this.imprimirCodigoProdutoPreparo = 'Não',
    required this.estoque,
    required this.tamanho,
    required this.foto,
    required this.ativo,
    required this.descricao,
    required this.valorVenda,
    required this.categoria,
    required this.nomeCategoria,
    this.dataLancado,
    this.ativarEdQtd,
    this.ativarCustoDeProducao,
    this.novo = true,
    this.destinoDeImpressao,
    required this.habilTipo,
    this.habilItensRetirada,
    this.ativoLoja,
    this.tamanhosPizza,
    // required this.cortesias,
    // required this.kits,
    // required this.adicionais,
    // required this.acompanhamentos,
    // required this.tamanhos,
    // required this.itensRetiradas,
    required this.ingredientes,
    this.quantidade,
    this.quantidadePessoa = 1,
    this.tamanhoLista,
    this.valorTotalVendas,
    this.observacao,
    this.quantidadeController,
    this.acoes,
    this.valorRestoDivisao,
    this.opcoesPacotes,
    this.opcoesPacotesListaFinal,
    this.descontoProduto,
    this.habilsepardelivery,
    this.idCategoriaCardapio,
    this.limiteSaboresBorda,
    this.conferidoNoCarrinho = false,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'iditensvenda': iditensvenda,
      'versaoEdicao': versaoEdicao,
      'hashprodutos': hashprodutos,
      'nome': nome,
      'codigo': codigo,
      'imprimirCodigoProdutoPreparo': imprimirCodigoProdutoPreparo,
      'estoque': estoque,
      'tamanho': tamanho,
      'foto': foto,
      'ativo': ativo,
      'descricao': descricao,
      'valorVenda': valorVenda,
      'categoria': categoria,
      'nomeCategoria': nomeCategoria,
      'dataLancado': dataLancado,
      'ativarEdQtd': ativarEdQtd,
      'ativarCustoDeProducao': ativarCustoDeProducao,
      'novo': novo,
      'destinoDeImpressao': destinoDeImpressao?.toMap(),
      'habilTipo': habilTipo,
      'ativoLoja': ativoLoja,
      'tamanhosPizza': tamanhosPizza?.map((x) => x.toMap()).toList(),
      // 'cortesias': cortesias.map((x) => x.toMap()).toList(),
      // 'kits': kits.map((x) => x.toMap()).toList(),
      // 'adicionais': adicionais.map((x) => x.toMap()).toList(),
      // 'acompanhamentos': acompanhamentos.map((x) => x.toMap()).toList(),
      // 'tamanhos': tamanhos.map((x) => x.toMap()).toList(),
      // 'itensRetiradas': itensRetiradas.map((x) => x.toMap()).toList(),
      'ingredientes': ingredientes.map((x) => x.toMap()).toList(),
      'quantidade': quantidade,
      'quantidadePessoa': quantidadePessoa,
      'tamanhoLista': tamanhoLista,
      'valorTotalVendas': valorTotalVendas,
      'observacao': observacao,
      'quantidadeController': quantidadeController,
      'acoes': acoes,
      'habilItensRetirada': habilItensRetirada,
      'valorRestoDivisao': valorRestoDivisao,
      'opcoesPacotes': opcoesPacotes?.map((x) => x.toMap()).toList(),
      'opcoesPacotesListaFinal':
          opcoesPacotesListaFinal?.map((x) => x.toMap()).toList(),
      'descontoProduto': descontoProduto?.toMap(),
      'habilsepardelivery': habilsepardelivery,
      'idCategoriaCardapio': idCategoriaCardapio,
      'categoriaCardapio': idCategoriaCardapio,
      'id_categoria_cardapio': idCategoriaCardapio,
      'categoria_cardapio': idCategoriaCardapio,
      'limiteSaboresBorda': limiteSaboresBorda,
      'conferidoNoCarrinho': conferidoNoCarrinho,
    };
  }

  factory Modelowordprodutos.fromMap(Map<String, dynamic> map) {
    return Modelowordprodutos(
      id: _texto(map['id']),
      conferidoNoCarrinho: _boolOpcional(map['conferidoNoCarrinho']) == true,
      limiteSaboresBorda: _inteiroOpcional(map['limiteSaboresBorda']),
      hashprodutos: map['hashprodutos']?.toString(),
      iditensvenda: (map['iditensvenda'] ?? map['id_itens_venda'])?.toString(),
      versaoEdicao: map['versaoEdicao']?.toString(),
      nome: _texto(map['nome']),
      codigo: _texto(map['codigo']),
      imprimirCodigoProdutoPreparo: (map['imprimirCodigoProdutoPreparo'] ??
                  map['imprimir_codigo_produto_preparo'])
              ?.toString() ??
          'Não',
      estoque: _texto(map['estoque']),
      tamanho: _texto(map['tamanho']),
      foto: _texto(map['foto']),
      ativo: _texto(map['ativo']),
      descricao: _texto(map['descricao']),
      valorVenda: _texto(map['valorVenda'], '0'),
      categoria: _texto(map['categoria']),
      nomeCategoria: _texto(map['nomeCategoria']),
      dataLancado: map['dataLancado']?.toString(),
      habilsepardelivery: map['habilsepardelivery']?.toString(),
      idCategoriaCardapio: map['idCategoriaCardapio']?.toString() ??
          map['categoriaCardapio']?.toString() ??
          map['id_categoria_cardapio']?.toString() ??
          map['categoria_cardapio']?.toString(),
      ativarCustoDeProducao: map['ativarCustoDeProducao']?.toString(),
      novo: _boolOpcional(map['novo']),
      destinoDeImpressao: _mapa(map['destinoDeImpressao']) != null
          ? ModeloDestinoImpressao.fromMap(_mapa(map['destinoDeImpressao'])!)
          : null,
      habilTipo: _texto(map['habilTipo']),
      habilItensRetirada: map['habilItensRetirada']?.toString(),
      ativoLoja: map['ativoLoja']?.toString(),
      // cortesias: List<Modelowordcortesiasproduto>.from(
      //   (map['cortesias'] as List<dynamic>).map<Modelowordcortesiasproduto>(
      //     (x) => Modelowordcortesiasproduto.fromMap(x as Map<String, dynamic>),
      //   ),
      // ),
      // kits: List<Modelowordprodutos>.from(
      //   (map['kits'] as List<dynamic>).map<Modelowordprodutos>(
      //     (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
      //   ),
      // ),
      // adicionais: List<Modelowordadicionaisproduto>.from(
      //   (map['adicionais'] as List<dynamic>).map<Modelowordadicionaisproduto>(
      //     (x) => Modelowordadicionaisproduto.fromMap(x as Map<String, dynamic>),
      //   ),
      // ),
      // acompanhamentos: List<Modelowordacompanhamentosproduto>.from(
      //   (map['acompanhamentos'] as List<dynamic>).map<Modelowordacompanhamentosproduto>(
      //     (x) => Modelowordacompanhamentosproduto.fromMap(x as Map<String, dynamic>),
      //   ),
      // ),
      // tamanhos: List<Modelowordtamanhosproduto>.from(
      //   (map['tamanhos'] as List<dynamic>).map<Modelowordtamanhosproduto>(
      //     (x) => Modelowordtamanhosproduto.fromMap(x as Map<String, dynamic>),
      //   ),
      // ),
      // itensRetiradas: List<Modeloworditensretiradaproduto>.from(
      //   (map['itensRetiradas'] as List<dynamic>).map<Modeloworditensretiradaproduto>(
      //     (x) => Modeloworditensretiradaproduto.fromMap(x as Map<String, dynamic>),
      //   ),
      // ),
      ingredientes: _ingredientes(map['ingredientes']),
      quantidade: _decimalOpcional(map['quantidade']),
      quantidadePessoa: _inteiroOpcional(map['quantidadePessoa']),
      tamanhoLista: _inteiroOpcional(map['tamanhoLista']),
      valorTotalVendas: map['valorTotalVendas']?.toString(),
      observacao: map['observacao']?.toString(),
      quantidadeController: map['quantidadeController'] is TextEditingController
          ? map['quantidadeController'] as TextEditingController
          : null,
      acoes: map['acoes'] is Widget ? map['acoes'] as Widget : null,
      valorRestoDivisao: map['valorRestoDivisao']?.toString(),
      opcoesPacotes: _opcoes(map['opcoesPacotes']),
      opcoesPacotesListaFinal: _opcoes(map['opcoesPacotesListaFinal']),
      tamanhosPizza: _tamanhosPizza(map['tamanhosPizza']),
      descontoProduto: _mapa(map['descontoProduto']) != null
          ? ModeloDescontoProduto.fromMap(_mapa(map['descontoProduto'])!)
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordprodutos.fromJson(String source) =>
      Modelowordprodutos.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(covariant Modelowordprodutos other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.nome == nome &&
        other.codigo == codigo &&
        other.imprimirCodigoProdutoPreparo == imprimirCodigoProdutoPreparo &&
        other.estoque == estoque &&
        other.tamanho == tamanho &&
        other.foto == foto &&
        other.ativo == ativo &&
        other.descricao == descricao &&
        other.valorVenda == valorVenda &&
        other.categoria == categoria &&
        other.nomeCategoria == nomeCategoria &&
        other.dataLancado == dataLancado &&
        other.novo == novo &&
        other.destinoDeImpressao == destinoDeImpressao &&
        other.habilTipo == habilTipo &&
        other.ativoLoja == ativoLoja &&
        // listEquals(other.adicionais, adicionais) &&
        // listEquals(other.acompanhamentos, acompanhamentos) &&
        // listEquals(other.tamanhos, tamanhos) &&
        // listEquals(other.itensRetiradas, itensRetiradas) &&
        // listEquals(other.ingredientes, ingredientes) &&
        other.quantidade == quantidade &&
        other.quantidadePessoa == quantidadePessoa &&
        other.tamanhoLista == tamanhoLista &&
        other.valorTotalVendas == valorTotalVendas &&
        other.observacao == observacao &&
        other.quantidadeController == quantidadeController &&
        other.acoes == acoes &&
        other.valorRestoDivisao == valorRestoDivisao;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        nome.hashCode ^
        codigo.hashCode ^
        imprimirCodigoProdutoPreparo.hashCode ^
        estoque.hashCode ^
        tamanho.hashCode ^
        foto.hashCode ^
        ativo.hashCode ^
        descricao.hashCode ^
        valorVenda.hashCode ^
        categoria.hashCode ^
        nomeCategoria.hashCode ^
        dataLancado.hashCode ^
        novo.hashCode ^
        destinoDeImpressao.hashCode ^
        habilTipo.hashCode ^
        ativoLoja.hashCode ^
        // adicionais.hashCode ^
        // acompanhamentos.hashCode ^
        // tamanhos.hashCode ^
        // itensRetiradas.hashCode ^
        ingredientes.hashCode ^
        quantidade.hashCode ^
        quantidadePessoa.hashCode ^
        tamanhoLista.hashCode ^
        valorTotalVendas.hashCode ^
        observacao.hashCode ^
        quantidadeController.hashCode ^
        valorRestoDivisao.hashCode ^
        acoes.hashCode;
  }
}
