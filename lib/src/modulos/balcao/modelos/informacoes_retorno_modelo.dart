// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class InformacoesRetornoModelo {
  final String cliente;
  final String nomeCliente;
  final String nomevendedor;
  final String nometransportadora;
  final String nomenatureza;
  final String naturezaoperacao;
  final String idvendedor;
  final String placadoveiculo;
  final String ufdoveiculo;
  final String quantidadetrans;
  final String especietrans;
  final String marcatrans;
  final String numeracaotrans;
  final String pesobrutotrans;
  final String pesoliquidotrans;
  final String tiponfreferenciada;
  final String chaveacessonferef;
  final String tipodeopacaosaida;
  final String idtransportadora;
  final String freteporconta;
  final String nomefreteporconta;
  final String status;
  final String cependerecocliente;
  final String enderecoenderecocliente;
  final String numeroenderecocliente;
  final String complementoenderecocliente;
  final String nomebairro;
  final String nomecidade;
  final String nomeestado;
  final bool temendereco;
  final String celularcliente;
  final String celularempresa;
  final String nomeempresa;
  final String telefonecliente;
  final String datalanc;
  final String valorcredito;
  final String numerodopedido;
  final String numeronf;
  final String acrescimo;
  final String valorvaletroca;
  final String descontopercentual;
  final String desconto;
  final String valordodesconto;
  final String subtotal;
  final String valortotalmodal;
  final String quantidadetotalmodal;
  final String descricaoDoCliente;
  final String resumoFinal;
  final String dadosAdicionais;
  final String observacoesInterna;
  final String observacoesDoCliente;
  final String tipodemodulo;
  final String dataaprovacao;
  final String dataprevisao;
  final String descricaotxt;
  final String descricaodoclientetxt;
  final String resumofinaltxt;
  final String docempresa;
  final String dataemissao;
  final String cp15;
  final String statusSefaz;
  final String idcomandapedido;
  final String idcomanda;
  final String idmesa;
  final String enderecoempresa;
  final String tipodeentrega;
  final String valortroco;
  final String valorentrega;
  final String dataAbertura;
  final String? motivoCancelamento;
  final String? observacaoDoPedido;

  InformacoesRetornoModelo({
    required this.cliente,
    required this.nomeCliente,
    required this.nomevendedor,
    required this.nometransportadora,
    required this.nomenatureza,
    required this.naturezaoperacao,
    required this.idvendedor,
    required this.placadoveiculo,
    required this.ufdoveiculo,
    required this.quantidadetrans,
    required this.especietrans,
    required this.marcatrans,
    required this.numeracaotrans,
    required this.pesobrutotrans,
    required this.pesoliquidotrans,
    required this.tiponfreferenciada,
    required this.chaveacessonferef,
    required this.tipodeopacaosaida,
    required this.idtransportadora,
    required this.freteporconta,
    required this.nomefreteporconta,
    required this.status,
    required this.cependerecocliente,
    required this.enderecoenderecocliente,
    required this.numeroenderecocliente,
    required this.complementoenderecocliente,
    required this.nomebairro,
    required this.nomecidade,
    required this.nomeestado,
    required this.temendereco,
    required this.celularcliente,
    required this.celularempresa,
    required this.nomeempresa,
    required this.telefonecliente,
    required this.datalanc,
    required this.valorcredito,
    required this.numerodopedido,
    required this.numeronf,
    required this.acrescimo,
    required this.valorvaletroca,
    required this.descontopercentual,
    required this.desconto,
    required this.valordodesconto,
    required this.subtotal,
    required this.valortotalmodal,
    required this.quantidadetotalmodal,
    required this.descricaoDoCliente,
    required this.resumoFinal,
    required this.dadosAdicionais,
    required this.observacoesInterna,
    required this.observacoesDoCliente,
    required this.tipodemodulo,
    required this.dataaprovacao,
    required this.dataprevisao,
    required this.descricaotxt,
    required this.descricaodoclientetxt,
    required this.resumofinaltxt,
    required this.docempresa,
    required this.dataemissao,
    required this.cp15,
    required this.statusSefaz,
    required this.idcomandapedido,
    required this.idcomanda,
    required this.idmesa,
    required this.enderecoempresa,
    required this.tipodeentrega,
    required this.valortroco,
    required this.valorentrega,
    required this.dataAbertura,
    this.motivoCancelamento,
    this.observacaoDoPedido,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'cliente': cliente,
      'nomeCliente': nomeCliente,
      'nomevendedor': nomevendedor,
      'nometransportadora': nometransportadora,
      'nomenatureza': nomenatureza,
      'naturezaoperacao': naturezaoperacao,
      'idvendedor': idvendedor,
      'placadoveiculo': placadoveiculo,
      'ufdoveiculo': ufdoveiculo,
      'quantidadetrans': quantidadetrans,
      'especietrans': especietrans,
      'marcatrans': marcatrans,
      'numeracaotrans': numeracaotrans,
      'pesobrutotrans': pesobrutotrans,
      'pesoliquidotrans': pesoliquidotrans,
      'tiponfreferenciada': tiponfreferenciada,
      'chaveacessonferef': chaveacessonferef,
      'tipodeopacaosaida': tipodeopacaosaida,
      'idtransportadora': idtransportadora,
      'freteporconta': freteporconta,
      'nomefreteporconta': nomefreteporconta,
      'status': status,
      'cependerecocliente': cependerecocliente,
      'enderecoenderecocliente': enderecoenderecocliente,
      'numeroenderecocliente': numeroenderecocliente,
      'complementoenderecocliente': complementoenderecocliente,
      'nomebairro': nomebairro,
      'nomecidade': nomecidade,
      'nomeestado': nomeestado,
      'temendereco': temendereco,
      'celularcliente': celularcliente,
      'celularempresa': celularempresa,
      'nomeempresa': nomeempresa,
      'telefonecliente': telefonecliente,
      'datalanc': datalanc,
      'valorcredito': valorcredito,
      'numerodopedido': numerodopedido,
      'numeronf': numeronf,
      'acrescimo': acrescimo,
      'valorvaletroca': valorvaletroca,
      'descontopercentual': descontopercentual,
      'desconto': desconto,
      'valordodesconto': valordodesconto,
      'subtotal': subtotal,
      'valortotalmodal': valortotalmodal,
      'quantidadetotalmodal': quantidadetotalmodal,
      'descricaoDoCliente': descricaoDoCliente,
      'resumoFinal': resumoFinal,
      'dadosAdicionais': dadosAdicionais,
      'observacoesInterna': observacoesInterna,
      'observacoesDoCliente': observacoesDoCliente,
      'tipodemodulo': tipodemodulo,
      'dataaprovacao': dataaprovacao,
      'dataprevisao': dataprevisao,
      'descricaotxt': descricaotxt,
      'descricaodoclientetxt': descricaodoclientetxt,
      'resumofinaltxt': resumofinaltxt,
      'docempresa': docempresa,
      'dataemissao': dataemissao,
      'cp15': cp15,
      'statusSefaz': statusSefaz,
      'idcomandapedido': idcomandapedido,
      'idcomanda': idcomanda,
      'idmesa': idmesa,
      'enderecoempresa': enderecoempresa,
      'tipodeentrega': tipodeentrega,
      'valortroco': valortroco,
      'valorentrega': valorentrega,
      'dataAbertura': dataAbertura,
      'motivoCancelamento': motivoCancelamento,
      'observacaoDoPedido': observacaoDoPedido,
    };
  }

  factory InformacoesRetornoModelo.fromMap(Map<String, dynamic> map) {
    return InformacoesRetornoModelo(
      cliente: map['cliente'] as String,
      nomeCliente: map['nomeCliente'] as String,
      nomevendedor: map['nomevendedor'] as String,
      nometransportadora: map['nometransportadora'] as String,
      nomenatureza: map['nomenatureza'] as String,
      naturezaoperacao: map['naturezaoperacao'] as String,
      idvendedor: map['idvendedor'] as String,
      placadoveiculo: map['placadoveiculo'] as String,
      ufdoveiculo: map['ufdoveiculo'] as String,
      quantidadetrans: map['quantidadetrans'] as String,
      especietrans: map['especietrans'] as String,
      marcatrans: map['marcatrans'] as String,
      numeracaotrans: map['numeracaotrans'] as String,
      pesobrutotrans: map['pesobrutotrans'] as String,
      pesoliquidotrans: map['pesoliquidotrans'] as String,
      tiponfreferenciada: map['tiponfreferenciada'] as String,
      chaveacessonferef: map['chaveacessonferef'] as String,
      tipodeopacaosaida: map['tipodeopacaosaida'] as String,
      idtransportadora: map['idtransportadora'] as String,
      freteporconta: map['freteporconta'] as String,
      nomefreteporconta: map['nomefreteporconta'] as String,
      status: map['status'] as String,
      cependerecocliente: map['cependerecocliente'] as String,
      enderecoenderecocliente: map['enderecoenderecocliente'] as String,
      numeroenderecocliente: map['numeroenderecocliente'] as String,
      complementoenderecocliente: map['complementoenderecocliente'] as String,
      nomebairro: map['nomebairro'] as String,
      nomecidade: map['nomecidade'] as String,
      nomeestado: map['nomeestado'] as String,
      temendereco: map['temendereco'] as bool,
      celularcliente: map['celularcliente'] as String,
      celularempresa: map['celularempresa'] as String,
      nomeempresa: map['nomeempresa'] as String,
      telefonecliente: map['telefonecliente'] as String,
      datalanc: map['datalanc'] as String,
      valorcredito: map['valorcredito'] as String,
      numerodopedido: map['numerodopedido'] as String,
      numeronf: map['numeronf'] as String,
      acrescimo: map['acrescimo'] as String,
      valorvaletroca: map['valorvaletroca'] as String,
      descontopercentual: map['descontopercentual'] as String,
      desconto: map['desconto'] as String,
      valordodesconto: map['valordodesconto'] as String,
      subtotal: map['subtotal'] as String,
      valortotalmodal: map['valortotalmodal'] as String,
      quantidadetotalmodal: map['quantidadetotalmodal'] as String,
      descricaoDoCliente: map['descricaoDoCliente'] as String,
      resumoFinal: map['resumoFinal'] as String,
      dadosAdicionais: map['dadosAdicionais'] as String,
      observacoesInterna: map['observacoesInterna'] as String,
      observacoesDoCliente: map['observacoesDoCliente'] as String,
      tipodemodulo: map['tipodemodulo'] as String,
      dataaprovacao: map['dataaprovacao'] as String,
      dataprevisao: map['dataprevisao'] as String,
      descricaotxt: map['descricaotxt'] as String,
      descricaodoclientetxt: map['descricaodoclientetxt'] as String,
      resumofinaltxt: map['resumofinaltxt'] as String,
      docempresa: map['docempresa'] as String,
      dataemissao: map['dataemissao'] as String,
      cp15: map['cp15'] as String,
      statusSefaz: map['statusSefaz'] as String,
      idcomandapedido: map['idcomandapedido'] as String,
      idcomanda: map['idcomanda'] as String,
      idmesa: map['idmesa'] as String,
      enderecoempresa: map['enderecoempresa'] as String,
      tipodeentrega: map['tipodeentrega'] as String,
      valortroco: map['valortroco'] as String,
      valorentrega: map['valorentrega'] as String,
      dataAbertura: map['dataAbertura'] as String,
      motivoCancelamento: map['motivoCancelamento'] != null ? map['motivoCancelamento'] as String : null,
      observacaoDoPedido: map['observacaoDoPedido'] != null ? map['observacaoDoPedido'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory InformacoesRetornoModelo.fromJson(String source) => InformacoesRetornoModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
