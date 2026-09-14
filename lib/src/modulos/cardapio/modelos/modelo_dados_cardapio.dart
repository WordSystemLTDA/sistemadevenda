import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';

String? _textoOpcional(Object? valor) => valor?.toString();

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

List<ModeloNomeLancamento>? _nomesLancamento(Object? valor) {
  if (valor is! List) return null;
  final nomes = <ModeloNomeLancamento>[];
  for (final item in valor) {
    if (item is! Map) continue;
    try {
      nomes.add(ModeloNomeLancamento.fromMap(Map<String, dynamic>.from(item)));
    } catch (_) {
      continue;
    }
  }
  return nomes;
}

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
  String? observacaoDoPedido;
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
    this.observacaoDoPedido,
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
      'observacaoDoPedido': observacaoDoPedido,
      'nomeMesa': nomeMesa,
      'tipodeentrega': tipodeentrega,
      'valorentrega': valorentrega,
    };
  }

  factory Modeloworddadoscardapio.fromMap(Map<String, dynamic> map) {
    return Modeloworddadoscardapio(
      id: _textoOpcional(map['id']),
      codigo: _textoOpcional(map['codigo']),
      nome: _textoOpcional(map['nome']),
      status: _textoOpcional(map['status']),
      dataAbertura: _textoOpcional(map['dataAbertura']),
      dataFechamento: _textoOpcional(map['dataFechamento']),
      dataUltimoProdutoInserido:
          _textoOpcional(map['dataUltimoProdutoInserido']),
      idCliente: _textoOpcional(map['idCliente']),
      nomeCliente: _textoOpcional(map['nomeCliente']),
      produtos: _produtos(map['produtos']),
      valorTotal: _textoOpcional(map['valorTotal']),
      numeroPedido: _textoOpcional(map['numeroPedido']),
      celularCliente: _textoOpcional(map['celularCliente']),
      enderecoCliente: _textoOpcional(map['enderecoCliente']),
      numeroCliente: _textoOpcional(map['numeroCliente']),
      complementoCliente: _textoOpcional(map['complementoCliente']),
      cidadeCliente: _textoOpcional(map['cidadeCliente']),
      bairroCliente: _textoOpcional(map['bairroCliente']),
      taxaBairroCliente: _textoOpcional(map['taxaBairroCliente']),
      somaValorHistorico: _textoOpcional(map['somaValorHistorico']),
      celularEmpresa: _textoOpcional(map['celularEmpresa']),
      cnpjEmpresa: _textoOpcional(map['cnpjEmpresa']),
      enderecoEmpresa: _textoOpcional(map['enderecoEmpresa']),
      nomeEmpresa: _textoOpcional(map['nomeEmpresa']),
      nomelancamento: _nomesLancamento(map['nomelancamento']),
      idComanda: _textoOpcional(map['idComanda']),
      idMesa: _textoOpcional(map['idMesa']),
      idDelivery: _textoOpcional(map['idDelivery']),
      idBalcao: _textoOpcional(map['idBalcao']),
      observacaoDoPedido: _textoOpcional(map['observacaoDoPedido']),
      nomeMesa: _textoOpcional(map['nomeMesa']),
      tipodeentrega: _textoOpcional(map['tipodeentrega']),
      valorentrega: _textoOpcional(map['valorentrega']),
    );
  }

  String toJson() => json.encode(toMap());

  factory Modeloworddadoscardapio.fromJson(String source) =>
      Modeloworddadoscardapio.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
