import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class Modeloworddadoscardapio {
  String? id;
  String? codigo;
  String? nome;
  String? status;
  String? dataAbertura;
  String? dataFechamento;
  String? dataUltimoProdutoInserido;
  String? idCliente;
  String? nomeCliente;
  List<Modelowordprodutos>? produtos;

  String? valorTotal;
  String? numeroPedido;
  String? celularCliente;
  String? enderecoCliente;
  String? numeroCliente;
  String? complementoCliente;
  String? cidadeCliente;
  String? bairroCliente;
  String? taxaBairroCliente;
  String? somaValorHistorico;
  String? celularEmpresa;
  String? cnpjEmpresa;
  String? enderecoEmpresa;
  String? nomeEmpresa;
  List<ModeloNomeLancamento>? nomelancamento;
  String? idComanda;
  String? idMesa;
  String? idDelivery;
  String? idBalcao;
  String? observacoes;
  String? nomeMesa;
  String? tipodeentrega;
  String? valorentrega;

  Modeloworddadoscardapio({
    this.id,
    this.codigo,
    this.nome,
    this.status,
    this.dataAbertura,
    this.dataFechamento,
    this.dataUltimoProdutoInserido,
    this.idCliente,
    this.nomeCliente,
    this.produtos,
    this.valorTotal,
    this.numeroPedido,
    this.celularCliente,
    this.enderecoCliente,
    this.numeroCliente,
    this.complementoCliente,
    this.cidadeCliente,
    this.bairroCliente,
    this.taxaBairroCliente,
    this.somaValorHistorico,
    this.celularEmpresa,
    this.cnpjEmpresa,
    this.enderecoEmpresa,
    this.nomeEmpresa,
    this.nomelancamento,
    this.idComanda,
    this.idMesa,
    this.idDelivery,
    this.idBalcao,
    this.observacoes,
    this.nomeMesa,
    this.tipodeentrega,
    this.valorentrega,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'codigo': codigo,
      'nome': nome,
      'status': status,
      'dataAbertura': dataAbertura,
      'dataFechamento': dataFechamento,
      'dataUltimoProdutoInserido': dataUltimoProdutoInserido,
      'idCliente': idCliente,
      'nomeCliente': nomeCliente,
      'produtos': produtos?.map((x) => x.toMap()).toList(),
      'valorTotal': valorTotal,
      'numeroPedido': numeroPedido,
      'celularCliente': celularCliente,
      'enderecoCliente': enderecoCliente,
      'numeroCliente': numeroCliente,
      'complementoCliente': complementoCliente,
      'cidadeCliente': cidadeCliente,
      'bairroCliente': bairroCliente,
      'taxaBairroCliente': taxaBairroCliente,
      'somaValorHistorico': somaValorHistorico,
      'celularEmpresa': celularEmpresa,
      'cnpjEmpresa': cnpjEmpresa,
      'enderecoEmpresa': enderecoEmpresa,
      'nomeEmpresa': nomeEmpresa,
      'nomelancamento': nomelancamento?.map((x) => x.toMap()).toList(),
      'idComanda': idComanda,
      'idMesa': idMesa,
      'idDelivery': idDelivery,
      'idBalcao': idBalcao,
      'observacoes': observacoes,
      'nomeMesa': nomeMesa,
      'tipodeentrega': tipodeentrega,
      'valorentrega': valorentrega,
    };
  }

  factory Modeloworddadoscardapio.fromMap(Map<String, dynamic> map) {
    return Modeloworddadoscardapio(
      id: map['id'] != null ? map['id'] as String : null,
      codigo: map['codigo'] != null ? map['codigo'] as String : null,
      nome: map['nome'] != null ? map['nome'] as String : null,
      status: map['status'] != null ? map['status'] as String : null,
      dataAbertura: map['dataAbertura'] != null ? map['dataAbertura'] as String : null,
      dataFechamento: map['dataFechamento'] != null ? map['dataFechamento'] as String : null,
      dataUltimoProdutoInserido: map['dataUltimoProdutoInserido'] != null ? map['dataUltimoProdutoInserido'] as String : null,
      idCliente: map['idCliente'] != null ? map['idCliente'] as String : null,
      nomeCliente: map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      produtos: map['produtos'] != null
          ? List<Modelowordprodutos>.from(
              (map['produtos'] as List<dynamic>).map<Modelowordprodutos?>(
                (x) => Modelowordprodutos.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      valorTotal: map['valorTotal'] != null ? map['valorTotal'] as String : null,
      numeroPedido: map['numeroPedido'] != null ? map['numeroPedido'] as String : null,
      celularCliente: map['celularCliente'] != null ? map['celularCliente'] as String : null,
      enderecoCliente: map['enderecoCliente'] != null ? map['enderecoCliente'] as String : null,
      numeroCliente: map['numeroCliente'] != null ? map['numeroCliente'] as String : null,
      complementoCliente: map['complementoCliente'] != null ? map['complementoCliente'] as String : null,
      cidadeCliente: map['cidadeCliente'] != null ? map['cidadeCliente'] as String : null,
      bairroCliente: map['bairroCliente'] != null ? map['bairroCliente'] as String : null,
      taxaBairroCliente: map['taxaBairroCliente'] != null ? map['taxaBairroCliente'] as String : null,
      somaValorHistorico: map['somaValorHistorico'] != null ? map['somaValorHistorico'] as String : null,
      celularEmpresa: map['celularEmpresa'] != null ? map['celularEmpresa'] as String : null,
      cnpjEmpresa: map['cnpjEmpresa'] != null ? map['cnpjEmpresa'] as String : null,
      enderecoEmpresa: map['enderecoEmpresa'] != null ? map['enderecoEmpresa'] as String : null,
      nomeEmpresa: map['nomeEmpresa'] != null ? map['nomeEmpresa'] as String : null,
      nomelancamento: map['nomelancamento'] != null
          ? List<ModeloNomeLancamento>.from(
              (map['nomelancamento'] as List<dynamic>).map<ModeloNomeLancamento?>(
                (x) => ModeloNomeLancamento.fromMap(x as Map<String, dynamic>),
              ),
            )
          : null,
      idComanda: map['idComanda'] != null ? map['idComanda'] as String : null,
      idMesa: map['idMesa'] != null ? map['idMesa'] as String : null,
      idDelivery: map['idDelivery'] != null ? map['idDelivery'] as String : null,
      idBalcao: map['idBalcao'] != null ? map['idBalcao'] as String : null,
      observacoes: map['observacoes'] != null ? map['observacoes'] as String : null,
      nomeMesa: map['nomeMesa'] != null ? map['nomeMesa'] as String : null,
      tipodeentrega: map['tipodeentrega'] != null ? map['tipodeentrega'] as String : null,
      valorentrega: map['valorentrega'] != null ? map['valorentrega'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modeloworddadoscardapio.fromJson(String source) => Modeloworddadoscardapio.fromMap(json.decode(source) as Map<String, dynamic>);
}
