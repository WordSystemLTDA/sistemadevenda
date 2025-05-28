// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_desconto_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_ingredientes_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:flutter/material.dart';

class Modelowordprodutos {
  String id;
  String? hashprodutos;
  String? iditensvenda;
  String nome;
  String codigo;
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

  Modelowordprodutos({
    required this.id,
    this.iditensvenda,
    this.hashprodutos,
    required this.nome,
    required this.codigo,
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
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'iditensvenda': iditensvenda,
      'hashprodutos': hashprodutos,
      'nome': nome,
      'codigo': codigo,
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
      'opcoesPacotesListaFinal': opcoesPacotesListaFinal?.map((x) => x.toMap()).toList(),
      'descontoProduto': descontoProduto?.toMap(),
      'habilsepardelivery': habilsepardelivery,
    };
  }

  factory Modelowordprodutos.fromMap(Map<String, dynamic> map) {
    return Modelowordprodutos(
      id: map['id'] as String,
      hashprodutos: map['hashprodutos'] != null ? map['hashprodutos'] as String : null,
      iditensvenda: map['iditensvenda'] != null ? map['iditensvenda'] as String : null,
      nome: map['nome'] as String,
      codigo: map['codigo'] as String,
      estoque: map['estoque'] as String,
      tamanho: map['tamanho'] as String,
      foto: map['foto'] as String,
      ativo: map['ativo'] as String,
      descricao: map['descricao'] as String,
      valorVenda: map['valorVenda'] as String,
      categoria: map['categoria'] as String,
      nomeCategoria: map['nomeCategoria'] as String,
      dataLancado: map['dataLancado'] != null ? map['dataLancado'] as String : null,
      habilsepardelivery: map['habilsepardelivery'] != null ? map['habilsepardelivery'] as String : null,
      ativarCustoDeProducao: map['ativarCustoDeProducao'] != null ? map['ativarCustoDeProducao'] as String : null,
      novo: map['novo'] != null ? map['novo'] as bool : null,
      destinoDeImpressao: map['destinoDeImpressao'] != null ? ModeloDestinoImpressao.fromMap(map['destinoDeImpressao'] as Map<String, dynamic>) : null,
      habilTipo: map['habilTipo'] as String,
      habilItensRetirada: map['habilItensRetirada'] != null ? map['habilItensRetirada'] as String : null,
      ativoLoja: map['ativoLoja'] != null ? map['ativoLoja'] as String : null,
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
      ingredientes: List<Modelowordingredientesproduto>.from(
        (map['ingredientes'] as List<dynamic>).map<Modelowordingredientesproduto>(
          (x) => Modelowordingredientesproduto.fromMap(x as Map<String, dynamic>),
        ),
      ),
      quantidade: map['quantidade'] != null
          ? (map['quantidade'] is int || map['quantidade'] is double)
              ? (double.tryParse(map['quantidade'].toString()) ?? 0)
              : (double.tryParse(map['quantidade']) ?? 0)
          : null,
      quantidadePessoa: map['quantidadePessoa'] != null ? map['quantidadePessoa'] as int : null,
      tamanhoLista: map['tamanhoLista'] != null ? map['tamanhoLista'] as int : null,
      valorTotalVendas: map['valorTotalVendas'] != null ? map['valorTotalVendas'] as String : null,
      observacao: map['observacao'] != null ? map['observacao'] as String : null,
      quantidadeController: map['quantidadeController'] != null ? map['quantidadeController'] as TextEditingController : null,
      acoes: map['acoes'] != null ? map['acoes'] as Widget : null,
      valorRestoDivisao: map['valorRestoDivisao'] != null ? map['valorRestoDivisao'] as String : null,
      opcoesPacotes: map['opcoesPacotes'] != null
          ? List<ModeloOpcoesPacotes>.from(
              (map['opcoesPacotes'] as List<dynamic>).map<ModeloOpcoesPacotes?>(
                (x) => ModeloOpcoesPacotes.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      opcoesPacotesListaFinal: map['opcoesPacotesListaFinal'] != null
          ? List<ModeloOpcoesPacotes>.from(
              (map['opcoesPacotesListaFinal'] as List<dynamic>).map<ModeloOpcoesPacotes?>(
                (x) => ModeloOpcoesPacotes.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      tamanhosPizza: map['tamanhosPizza'] != null
          ? List<Modelowordtamanhosproduto>.from(
              (map['tamanhosPizza'] as List<dynamic>).map<Modelowordtamanhosproduto?>(
                (x) => Modelowordtamanhosproduto.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      descontoProduto: map['descontoProduto'] != null ? ModeloDescontoProduto.fromMap(map['descontoProduto'] as Map<String, dynamic>) : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordprodutos.fromJson(String source) => Modelowordprodutos.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(covariant Modelowordprodutos other) {
    if (identical(this, other)) return true;

    return other.id == id &&
        other.nome == nome &&
        other.codigo == codigo &&
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
