// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/produto_tela_nfe_saida_modelo.dart';

class SalvarListarVendasModelo {
  final String idVenda;
  final List<ProdutoTelaNfeSaidaModelo> produtos;
  final List<ParcelasModelo> parcelasLista;
  final String desconto;
  final String? numeroPedido;
  final String? horaLanc;
  final String? formaDePagamento;
  final String acrescimo;
  final String dataLancamento;
  final String subTotalNovo;
  final String idVendedor;
  final String idCliente;
  final String? razaoSocialCliente;
  final String? celularCliente;
  final String? statusSefaz;
  final String notaFiscal;
  final String parcelas;
  final String descontoPercentual;
  final String valorTroco;
  final String moviDinheiro;
  final String moviPromissoria;
  final String moviCartaoDebito;
  final String moviCartaoCredito;
  final String moviPix;
  final String moviOp2;
  final String moviOp3;
  final String moviOp4;
  final String moviOp5;
  final String totalAReceber;
  final String totalRecebido;
  final String valorFalta;
  final String data;
  final String idNatureza;
  final String emissaoDeNota;
  final String tipoDePessoa;
  final String docDePessoa;
  final String idTransportadoraNfe;
  final String fretePorContaNfe;
  final String placaDoVeiculoNfe;
  final String ufDoVeiculoNfe;
  final String quantidadeTransNfe;
  final String especieTransNfe;
  final String marcaTransNfe;
  final String numeracaoTransNfe;
  final String pesoBrutoTransNfe;
  final String pesoLiquidoTransNfe;
  final String tipoNfReferenciadaNfe;
  final String chaveAcessoNfeRefNfe;
  final String idDescricao;
  final String descricaoDoCliente;
  final String resumoFinal;
  final String dadosAdicionais;
  final String observacoesInterna;
  final String observacoesDoCliente;
  final String? stiloStatus3;
  final String? tipodemodulo;
  final String? nomeDoModelo;
  final String? cp17;
  final String? cp25;
  final String? cp18;

  SalvarListarVendasModelo({
    required this.idVenda,
    required this.produtos,
    required this.parcelasLista,
    required this.desconto,
    this.numeroPedido,
    this.horaLanc,
    this.formaDePagamento,
    required this.acrescimo,
    required this.dataLancamento,
    required this.subTotalNovo,
    required this.idVendedor,
    required this.idCliente,
    this.razaoSocialCliente,
    this.celularCliente,
    this.statusSefaz,
    required this.notaFiscal,
    required this.parcelas,
    required this.descontoPercentual,
    required this.valorTroco,
    required this.moviDinheiro,
    required this.moviPromissoria,
    required this.moviCartaoDebito,
    required this.moviCartaoCredito,
    required this.moviPix,
    required this.moviOp2,
    required this.moviOp3,
    required this.moviOp4,
    required this.moviOp5,
    required this.totalAReceber,
    required this.totalRecebido,
    required this.valorFalta,
    required this.data,
    required this.idNatureza,
    required this.emissaoDeNota,
    required this.tipoDePessoa,
    required this.docDePessoa,
    required this.idTransportadoraNfe,
    required this.fretePorContaNfe,
    required this.placaDoVeiculoNfe,
    required this.ufDoVeiculoNfe,
    required this.quantidadeTransNfe,
    required this.especieTransNfe,
    required this.marcaTransNfe,
    required this.numeracaoTransNfe,
    required this.pesoBrutoTransNfe,
    required this.pesoLiquidoTransNfe,
    required this.tipoNfReferenciadaNfe,
    required this.chaveAcessoNfeRefNfe,
    required this.idDescricao,
    required this.descricaoDoCliente,
    required this.resumoFinal,
    required this.dadosAdicionais,
    required this.observacoesInterna,
    required this.observacoesDoCliente,
    this.stiloStatus3,
    this.tipodemodulo,
    this.nomeDoModelo,
    this.cp17,
    this.cp25,
    this.cp18,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'idVenda': idVenda,
      'produtos': produtos.map((x) => x.toMap()).toList(),
      'parcelasLista': parcelasLista.map((x) => x.toMap()).toList(),
      'desconto': desconto,
      'numeroPedido': numeroPedido,
      'horaLanc': horaLanc,
      'formaDePagamento': formaDePagamento,
      'acrescimo': acrescimo,
      'dataLancamento': dataLancamento,
      'subTotalNovo': subTotalNovo,
      'idVendedor': idVendedor,
      'idCliente': idCliente,
      'razaoSocialCliente': razaoSocialCliente,
      'celularCliente': celularCliente,
      'statusSefaz': statusSefaz,
      'notaFiscal': notaFiscal,
      'parcelas': parcelas,
      'descontoPercentual': descontoPercentual,
      'valorTroco': valorTroco,
      'moviDinheiro': moviDinheiro,
      'moviPromissoria': moviPromissoria,
      'moviCartaoDebito': moviCartaoDebito,
      'moviCartaoCredito': moviCartaoCredito,
      'moviPix': moviPix,
      'moviOp2': moviOp2,
      'moviOp3': moviOp3,
      'moviOp4': moviOp4,
      'moviOp5': moviOp5,
      'totalAReceber': totalAReceber,
      'totalRecebido': totalRecebido,
      'valorFalta': valorFalta,
      'data': data,
      'idNatureza': idNatureza,
      'emissaoDeNota': emissaoDeNota,
      'tipoDePessoa': tipoDePessoa,
      'docDePessoa': docDePessoa,
      'idTransportadoraNfe': idTransportadoraNfe,
      'fretePorContaNfe': fretePorContaNfe,
      'placaDoVeiculoNfe': placaDoVeiculoNfe,
      'ufDoVeiculoNfe': ufDoVeiculoNfe,
      'quantidadeTransNfe': quantidadeTransNfe,
      'especieTransNfe': especieTransNfe,
      'marcaTransNfe': marcaTransNfe,
      'numeracaoTransNfe': numeracaoTransNfe,
      'pesoBrutoTransNfe': pesoBrutoTransNfe,
      'pesoLiquidoTransNfe': pesoLiquidoTransNfe,
      'tipoNfReferenciadaNfe': tipoNfReferenciadaNfe,
      'chaveAcessoNfeRefNfe': chaveAcessoNfeRefNfe,
      'idDescricao': idDescricao,
      'descricaoDoCliente': descricaoDoCliente,
      'resumoFinal': resumoFinal,
      'dadosAdicionais': dadosAdicionais,
      'observacoesInterna': observacoesInterna,
      'observacoesDoCliente': observacoesDoCliente,
      'stiloStatus3': stiloStatus3,
      'tipodemodulo': tipodemodulo,
      'nomeDoModelo': nomeDoModelo,
      'cp17': cp17,
      'cp25': cp25,
      'cp18': cp18,
    };
  }

  factory SalvarListarVendasModelo.fromMap(Map<String, dynamic> map) {
    return SalvarListarVendasModelo(
      idVenda: map['idVenda'] as String,
      produtos: List<ProdutoTelaNfeSaidaModelo>.from(
        (map['produtos'] as List<dynamic>).map<ProdutoTelaNfeSaidaModelo>(
          (x) => ProdutoTelaNfeSaidaModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
      parcelasLista: List<ParcelasModelo>.from(
        (map['parcelasLista'] as List<dynamic>).map<ParcelasModelo>(
          (x) => ParcelasModelo.fromMap(x as Map<String, dynamic>),
        ),
      ),
      desconto: map['desconto'] as String,
      numeroPedido: map['numeroPedido'] != null ? map['numeroPedido'] as String : null,
      horaLanc: map['horaLanc'] != null ? map['horaLanc'] as String : null,
      formaDePagamento: map['formaDePagamento'] != null ? map['formaDePagamento'] as String : null,
      acrescimo: map['acrescimo'] as String,
      dataLancamento: map['dataLancamento'] as String,
      subTotalNovo: map['subTotalNovo'] as String,
      idVendedor: map['idVendedor'] as String,
      idCliente: map['idCliente'] as String,
      razaoSocialCliente: map['razaoSocialCliente'] != null ? map['razaoSocialCliente'] as String : null,
      celularCliente: map['celularCliente'] != null ? map['celularCliente'] as String : null,
      statusSefaz: map['statusSefaz'] != null ? map['statusSefaz'] as String : null,
      notaFiscal: map['notaFiscal'] as String,
      parcelas: map['parcelas'] as String,
      descontoPercentual: map['descontoPercentual'] as String,
      valorTroco: map['valorTroco'] as String,
      moviDinheiro: map['moviDinheiro'] as String,
      moviPromissoria: map['moviPromissoria'] as String,
      moviCartaoDebito: map['moviCartaoDebito'] as String,
      moviCartaoCredito: map['moviCartaoCredito'] as String,
      moviPix: map['moviPix'] as String,
      moviOp2: map['moviOp2'] as String,
      moviOp3: map['moviOp3'] as String,
      moviOp4: map['moviOp4'] as String,
      moviOp5: map['moviOp5'] as String,
      totalAReceber: map['totalAReceber'] as String,
      totalRecebido: map['totalRecebido'] as String,
      valorFalta: map['valorFalta'] as String,
      data: map['data'] as String,
      idNatureza: map['idNatureza'] as String,
      emissaoDeNota: map['emissaoDeNota'] as String,
      tipoDePessoa: map['tipoDePessoa'] as String,
      docDePessoa: map['docDePessoa'] as String,
      idTransportadoraNfe: map['idTransportadoraNfe'] as String,
      fretePorContaNfe: map['fretePorContaNfe'] as String,
      placaDoVeiculoNfe: map['placaDoVeiculoNfe'] as String,
      ufDoVeiculoNfe: map['ufDoVeiculoNfe'] as String,
      quantidadeTransNfe: map['quantidadeTransNfe'] as String,
      especieTransNfe: map['especieTransNfe'] as String,
      marcaTransNfe: map['marcaTransNfe'] as String,
      numeracaoTransNfe: map['numeracaoTransNfe'] as String,
      pesoBrutoTransNfe: map['pesoBrutoTransNfe'] as String,
      pesoLiquidoTransNfe: map['pesoLiquidoTransNfe'] as String,
      tipoNfReferenciadaNfe: map['tipoNfReferenciadaNfe'] as String,
      chaveAcessoNfeRefNfe: map['chaveAcessoNfeRefNfe'] as String,
      idDescricao: map['idDescricao'] as String,
      descricaoDoCliente: map['descricaoDoCliente'] as String,
      resumoFinal: map['resumoFinal'] as String,
      dadosAdicionais: map['dadosAdicionais'] as String,
      observacoesInterna: map['observacoesInterna'] as String,
      observacoesDoCliente: map['observacoesDoCliente'] as String,
      stiloStatus3: map['stiloStatus3'] != null ? map['stiloStatus3'] as String : null,
      tipodemodulo: map['tipodemodulo'] != null ? map['tipodemodulo'] as String : null,
      nomeDoModelo: map['nomeDoModelo'] != null ? map['nomeDoModelo'] as String : null,
      cp17: map['cp17'] != null ? map['cp17'] as String : null,
      cp25: map['cp25'] != null ? map['cp25'] as String : null,
      cp18: map['cp18'] != null ? map['cp18'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory SalvarListarVendasModelo.fromJson(String source) => SalvarListarVendasModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
