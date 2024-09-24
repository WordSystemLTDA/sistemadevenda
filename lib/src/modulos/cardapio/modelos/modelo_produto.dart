// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_acompanhamentos_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_adicionais_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_itens_retirada_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
import 'package:flutter/foundation.dart';

class ModeloProduto {
  String id;

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
  List<Modelowordadicionaisproduto> adicionais;
  List<Modelowordacompanhamentosproduto> acompanhamentos;
  List<Modelowordtamanhosproduto> tamanhos;
  List<Modeloworditensretiradaproduto> itensRetiradas;
  double? quantidade;
  int? quantidadePessoa;
  int? tamanhoLista;
  String? valorTotalVendas;
  String? observacao;

  String? valorRestoDivisao;
  List<ModeloOpcoesPacotes>? opcoesPacotes;

  ModeloProduto({
    required this.id,
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
    required this.adicionais,
    required this.acompanhamentos,
    required this.tamanhos,
    required this.itensRetiradas,
    this.quantidade,
    this.quantidadePessoa = 1,
    this.tamanhoLista,
    this.valorTotalVendas,
    this.observacao,
    this.valorRestoDivisao,
    this.opcoesPacotes,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
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
      'adicionais': adicionais.map((x) => x.toMap()).toList(),
      'acompanhamentos': acompanhamentos.map((x) => x.toMap()).toList(),
      'tamanhos': tamanhos.map((x) => x.toMap()).toList(),
      'itensRetiradas': itensRetiradas.map((x) => x.toMap()).toList(),
      'quantidade': quantidade,
      'quantidadePessoa': quantidadePessoa,
      'tamanhoLista': tamanhoLista,
      'valorTotalVendas': valorTotalVendas,
      'observacao': observacao,
      'habilItensRetirada': habilItensRetirada,
      'valorRestoDivisao': valorRestoDivisao,
      'opcoesPacotes': opcoesPacotes?.map((x) => x.toMap()).toList(),
    };
  }

  factory ModeloProduto.fromMap(Map<String, dynamic> map) {
    return ModeloProduto(
      id: map['id'] as String,
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
      ativarEdQtd: map['ativarEdQtd'] != null ? map['ativarEdQtd'] as String : null,
      ativarCustoDeProducao: map['ativarCustoDeProducao'] != null ? map['ativarCustoDeProducao'] as String : null,
      novo: map['novo'] != null ? map['novo'] as bool : null,
      destinoDeImpressao: map['destinoDeImpressao'] != null ? ModeloDestinoImpressao.fromMap(map['destinoDeImpressao'] as Map<String, dynamic>) : null,
      habilTipo: map['habilTipo'] as String,
      habilItensRetirada: map['habilItensRetirada'] != null ? map['habilItensRetirada'] as String : null,
      ativoLoja: map['ativoLoja'] != null ? map['ativoLoja'] as String : null,
      adicionais: List<Modelowordadicionaisproduto>.from(
        (map['adicionais'] as List<dynamic>).map<Modelowordadicionaisproduto>(
          (x) => Modelowordadicionaisproduto.fromMap(x as Map<String, dynamic>),
        ),
      ),
      acompanhamentos: List<Modelowordacompanhamentosproduto>.from(
        (map['acompanhamentos'] as List<dynamic>).map<Modelowordacompanhamentosproduto>(
          (x) => Modelowordacompanhamentosproduto.fromMap(x as Map<String, dynamic>),
        ),
      ),
      tamanhos: List<Modelowordtamanhosproduto>.from(
        (map['tamanhos'] as List<dynamic>).map<Modelowordtamanhosproduto>(
          (x) => Modelowordtamanhosproduto.fromMap(x as Map<String, dynamic>),
        ),
      ),
      itensRetiradas: List<Modeloworditensretiradaproduto>.from(
        (map['itensRetiradas'] as List<dynamic>).map<Modeloworditensretiradaproduto>(
          (x) => Modeloworditensretiradaproduto.fromMap(x as Map<String, dynamic>),
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
      valorRestoDivisao: map['valorRestoDivisao'] != null ? map['valorRestoDivisao'] as String : null,
      opcoesPacotes: map['opcoesPacotes'] != null
          ? List<ModeloOpcoesPacotes>.from(
              (map['opcoesPacotes'] as List<dynamic>).map<ModeloOpcoesPacotes?>(
                (x) => ModeloOpcoesPacotes.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloProduto.fromJson(String source) => ModeloProduto.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  bool operator ==(covariant ModeloProduto other) {
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
        listEquals(other.adicionais, adicionais) &&
        listEquals(other.acompanhamentos, acompanhamentos) &&
        listEquals(other.tamanhos, tamanhos) &&
        listEquals(other.itensRetiradas, itensRetiradas) &&
        other.quantidade == quantidade &&
        other.quantidadePessoa == quantidadePessoa &&
        other.tamanhoLista == tamanhoLista &&
        other.valorTotalVendas == valorTotalVendas &&
        other.observacao == observacao &&
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
        adicionais.hashCode ^
        acompanhamentos.hashCode ^
        tamanhos.hashCode ^
        itensRetiradas.hashCode ^
        quantidade.hashCode ^
        quantidadePessoa.hashCode ^
        tamanhoLista.hashCode ^
        valorTotalVendas.hashCode ^
        observacao.hashCode ^
        valorRestoDivisao.hashCode;
  }
}