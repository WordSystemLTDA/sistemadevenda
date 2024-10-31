import 'dart:convert';

class ListarVendasModelo {
  final String id;
  final String cp1;
  final String cp1F;
  final String cp2;
  final String cp3;
  final String cp4;
  final String cp5;
  final String cp100;
  final String cp6;
  final String cp7;
  final String cp7F;
  final String cp8;
  final String cp8F;
  final String valorCredito;
  final String valorCreditoF;
  final String cp9;
  final String cp9F;
  final String valorComCreditoTotal;
  final String valorComCreditoTotalF;
  final String cp10;
  final String cp11;
  final String cp12;
  final String cp13;
  final String cp14;
  final String cp15;
  final String cp16;
  final String cp17;
  final String cp18;
  final String cp19;
  final String dataEmissao;
  final String cp20;
  final String cp21;
  final String cp22;
  final String cp23;
  final String cp24;
  final String cp25;
  final String cp26;
  final String horaLanc;
  final String pago;
  final String cp30;
  final String cp31;
  final String cp32;
  final String dadosAdicionais;
  final String observacoesInterna;
  final String naturezaOperacao;
  final String idTransportadora;
  final String fretePorConta;
  final String placaDoVeiculo;
  final String ufDoVeiculo;
  final String quantidadeTrans;
  final String especieTrans;
  final String marcaTrans;
  final String numeracaoTrans;
  final String pesoBrutoTrans;
  final String pesoLiquidoTrans;
  final String idMedico;
  final String tipoDeOpacaoSaida;
  final String tipoNfReferenciada;
  final String chaveAcessoNfeRef;
  final String stilo1;
  final String stilo2;
  final String stilo3;
  final String ocultarReceberInscricao;
  final String numeroDoPedido;
  final String nomeCliente;
  final String numeroCartao;
  final String nomeEntradaSaida;
  final String formaDePagamento;
  final String separarPgto;
  final String idValeTroca;
  final String valorTotalListar;
  final String nomeDoModelo;
  final String numeroNotafiscal;
  final String statusSefaz;
  final String ocultarEnvioDeComprovanteGerencial;
  final String desabilitarNfe;
  final String ocultar;
  final String desabilitarModuloNfe;
  final String ocultarCondicional;
  final String titleCpfNota;
  final String desabilitarModuloNfce;
  final String desabilitarNfce;
  final String ocultarCpfNaNota;
  final String temInformacao;
  final String ocultarEmissaoNfce;
  final String habilitarCancelamentoNfe;
  final String habilitarCancelamentoNfce;
  final String ocultarWhatsapp;
  final String ocultarOpcaoesDeEnvio;
  final String ocultarEmailNota;
  final String titleFinalizar;
  final String mostrarOpcaoDeVenda;
  final String ativoNotaNfe;
  final String desabilitarCartaDeCorrecao;
  final String desabilitarCartaNfeCancelada;
  final String celularCliente;
  final String emailCliente;
  final String nomeVendedor;
  final String valorDoDescontoF;
  final String qtdItensTabela;
  final String quantProVenda;
  final String tipoDeRelatorio;
  final String desabilitarModuloFiscal;
  final String ativarIcone;
  final String corStatusSefaz;
  final String stiloStatus1;
  final String stiloStatus2;
  final String stiloStatus3;
  final String ativoNotaNfce;
  final String valorTotalF;
  final String tipodemodulo;
  final String docempresa;

  ListarVendasModelo({
    required this.id,
    required this.cp1,
    required this.cp1F,
    required this.cp2,
    required this.cp3,
    required this.cp4,
    required this.cp5,
    required this.cp100,
    required this.cp6,
    required this.cp7,
    required this.cp7F,
    required this.cp8,
    required this.cp8F,
    required this.valorCredito,
    required this.valorCreditoF,
    required this.cp9,
    required this.cp9F,
    required this.valorComCreditoTotal,
    required this.valorComCreditoTotalF,
    required this.cp10,
    required this.cp11,
    required this.cp12,
    required this.cp13,
    required this.cp14,
    required this.cp15,
    required this.cp16,
    required this.cp17,
    required this.cp18,
    required this.cp19,
    required this.dataEmissao,
    required this.cp20,
    required this.cp21,
    required this.cp22,
    required this.cp23,
    required this.cp24,
    required this.cp25,
    required this.cp26,
    required this.horaLanc,
    required this.pago,
    required this.cp30,
    required this.cp31,
    required this.cp32,
    required this.dadosAdicionais,
    required this.observacoesInterna,
    required this.naturezaOperacao,
    required this.idTransportadora,
    required this.fretePorConta,
    required this.placaDoVeiculo,
    required this.ufDoVeiculo,
    required this.quantidadeTrans,
    required this.especieTrans,
    required this.marcaTrans,
    required this.numeracaoTrans,
    required this.pesoBrutoTrans,
    required this.pesoLiquidoTrans,
    required this.idMedico,
    required this.tipoDeOpacaoSaida,
    required this.tipoNfReferenciada,
    required this.chaveAcessoNfeRef,
    required this.stilo1,
    required this.stilo2,
    required this.stilo3,
    required this.ocultarReceberInscricao,
    required this.numeroDoPedido,
    required this.nomeCliente,
    required this.numeroCartao,
    required this.nomeEntradaSaida,
    required this.formaDePagamento,
    required this.separarPgto,
    required this.idValeTroca,
    required this.valorTotalListar,
    required this.nomeDoModelo,
    required this.numeroNotafiscal,
    required this.statusSefaz,
    required this.ocultarEnvioDeComprovanteGerencial,
    required this.desabilitarNfe,
    required this.ocultar,
    required this.desabilitarModuloNfe,
    required this.ocultarCondicional,
    required this.titleCpfNota,
    required this.desabilitarModuloNfce,
    required this.desabilitarNfce,
    required this.ocultarCpfNaNota,
    required this.temInformacao,
    required this.ocultarEmissaoNfce,
    required this.habilitarCancelamentoNfe,
    required this.habilitarCancelamentoNfce,
    required this.ocultarWhatsapp,
    required this.ocultarOpcaoesDeEnvio,
    required this.ocultarEmailNota,
    required this.titleFinalizar,
    required this.mostrarOpcaoDeVenda,
    required this.ativoNotaNfe,
    required this.desabilitarCartaDeCorrecao,
    required this.desabilitarCartaNfeCancelada,
    required this.celularCliente,
    required this.emailCliente,
    required this.nomeVendedor,
    required this.valorDoDescontoF,
    required this.qtdItensTabela,
    required this.quantProVenda,
    required this.tipoDeRelatorio,
    required this.desabilitarModuloFiscal,
    required this.ativarIcone,
    required this.corStatusSefaz,
    required this.stiloStatus1,
    required this.stiloStatus2,
    required this.stiloStatus3,
    required this.ativoNotaNfce,
    required this.valorTotalF,
    required this.tipodemodulo,
    required this.docempresa,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'cp1': cp1,
      'cp1F': cp1F,
      'cp2': cp2,
      'cp3': cp3,
      'cp4': cp4,
      'cp5': cp5,
      'cp100': cp100,
      'cp6': cp6,
      'cp7': cp7,
      'cp7F': cp7F,
      'cp8': cp8,
      'cp8F': cp8F,
      'valorCredito': valorCredito,
      'valorCreditoF': valorCreditoF,
      'cp9': cp9,
      'cp9F': cp9F,
      'valorComCreditoTotal': valorComCreditoTotal,
      'valorComCreditoTotalF': valorComCreditoTotalF,
      'cp10': cp10,
      'cp11': cp11,
      'cp12': cp12,
      'cp13': cp13,
      'cp14': cp14,
      'cp15': cp15,
      'cp16': cp16,
      'cp17': cp17,
      'cp18': cp18,
      'cp19': cp19,
      'dataEmissao': dataEmissao,
      'cp20': cp20,
      'cp21': cp21,
      'cp22': cp22,
      'cp23': cp23,
      'cp24': cp24,
      'cp25': cp25,
      'cp26': cp26,
      'horaLanc': horaLanc,
      'pago': pago,
      'cp30': cp30,
      'cp31': cp31,
      'cp32': cp32,
      'dadosAdicionais': dadosAdicionais,
      'observacoesInterna': observacoesInterna,
      'naturezaOperacao': naturezaOperacao,
      'idTransportadora': idTransportadora,
      'fretePorConta': fretePorConta,
      'placaDoVeiculo': placaDoVeiculo,
      'ufDoVeiculo': ufDoVeiculo,
      'quantidadeTrans': quantidadeTrans,
      'especieTrans': especieTrans,
      'marcaTrans': marcaTrans,
      'numeracaoTrans': numeracaoTrans,
      'pesoBrutoTrans': pesoBrutoTrans,
      'pesoLiquidoTrans': pesoLiquidoTrans,
      'idMedico': idMedico,
      'tipoDeOpacaoSaida': tipoDeOpacaoSaida,
      'tipoNfReferenciada': tipoNfReferenciada,
      'chaveAcessoNfeRef': chaveAcessoNfeRef,
      'stilo1': stilo1,
      'stilo2': stilo2,
      'stilo3': stilo3,
      'ocultarReceberInscricao': ocultarReceberInscricao,
      'numeroDoPedido': numeroDoPedido,
      'nomeCliente': nomeCliente,
      'numeroCartao': numeroCartao,
      'nomeEntradaSaida': nomeEntradaSaida,
      'formaDePagamento': formaDePagamento,
      'separarPgto': separarPgto,
      'idValeTroca': idValeTroca,
      'valorTotalListar': valorTotalListar,
      'nomeDoModelo': nomeDoModelo,
      'numeroNotafiscal': numeroNotafiscal,
      'statusSefaz': statusSefaz,
      'ocultarEnvioDeComprovanteGerencial': ocultarEnvioDeComprovanteGerencial,
      'desabilitarNfe': desabilitarNfe,
      'ocultar': ocultar,
      'desabilitarModuloNfe': desabilitarModuloNfe,
      'ocultarCondicional': ocultarCondicional,
      'titleCpfNota': titleCpfNota,
      'desabilitarModuloNfce': desabilitarModuloNfce,
      'desabilitarNfce': desabilitarNfce,
      'ocultarCpfNaNota': ocultarCpfNaNota,
      'temInformacao': temInformacao,
      'ocultarEmissaoNfce': ocultarEmissaoNfce,
      'habilitarCancelamentoNfe': habilitarCancelamentoNfe,
      'habilitarCancelamentoNfce': habilitarCancelamentoNfce,
      'ocultarWhatsapp': ocultarWhatsapp,
      'ocultarOpcaoesDeEnvio': ocultarOpcaoesDeEnvio,
      'ocultarEmailNota': ocultarEmailNota,
      'titleFinalizar': titleFinalizar,
      'mostrarOpcaoDeVenda': mostrarOpcaoDeVenda,
      'ativoNotaNfe': ativoNotaNfe,
      'desabilitarCartaDeCorrecao': desabilitarCartaDeCorrecao,
      'desabilitarCartaNfeCancelada': desabilitarCartaNfeCancelada,
      'celularCliente': celularCliente,
      'emailCliente': emailCliente,
      'nomeVendedor': nomeVendedor,
      'valorDoDescontoF': valorDoDescontoF,
      'qtdItensTabela': qtdItensTabela,
      'quantProVenda': quantProVenda,
      'tipoDeRelatorio': tipoDeRelatorio,
      'desabilitarModuloFiscal': desabilitarModuloFiscal,
      'ativarIcone': ativarIcone,
      'corStatusSefaz': corStatusSefaz,
      'stiloStatus1': stiloStatus1,
      'stiloStatus2': stiloStatus2,
      'stiloStatus3': stiloStatus3,
      'ativoNotaNfce': ativoNotaNfce,
      'valorTotalF': valorTotalF,
      'tipodemodulo': tipodemodulo,
      'docempresa': docempresa,
    };
  }

  factory ListarVendasModelo.fromMap(Map<String, dynamic> map) {
    return ListarVendasModelo(
      id: map['id'] as String,
      cp1: map['cp1'] as String,
      cp1F: map['cp1F'] as String,
      cp2: map['cp2'] as String,
      cp3: map['cp3'] as String,
      cp4: map['cp4'] as String,
      cp5: map['cp5'] as String,
      cp100: map['cp100'] as String,
      cp6: map['cp6'] as String,
      cp7: map['cp7'] as String,
      cp7F: map['cp7F'] as String,
      cp8: map['cp8'] as String,
      cp8F: map['cp8F'] as String,
      valorCredito: map['valorCredito'] as String,
      valorCreditoF: map['valorCreditoF'] as String,
      cp9: map['cp9'] as String,
      cp9F: map['cp9F'] as String,
      valorComCreditoTotal: map['valorComCreditoTotal'] as String,
      valorComCreditoTotalF: map['valorComCreditoTotalF'] as String,
      cp10: map['cp10'] as String,
      cp11: map['cp11'] as String,
      cp12: map['cp12'] as String,
      cp13: map['cp13'] as String,
      cp14: map['cp14'] as String,
      cp15: map['cp15'] as String,
      cp16: map['cp16'] as String,
      cp17: map['cp17'] as String,
      cp18: map['cp18'] as String,
      cp19: map['cp19'] as String,
      dataEmissao: map['dataEmissao'] as String,
      cp20: map['cp20'] as String,
      cp21: map['cp21'] as String,
      cp22: map['cp22'] as String,
      cp23: map['cp23'] as String,
      cp24: map['cp24'] as String,
      cp25: map['cp25'] as String,
      cp26: map['cp26'] as String,
      horaLanc: map['horaLanc'] as String,
      pago: map['pago'] as String,
      cp30: map['cp30'] as String,
      cp31: map['cp31'] as String,
      cp32: map['cp32'] as String,
      dadosAdicionais: map['dadosAdicionais'] as String,
      observacoesInterna: map['observacoesInterna'] as String,
      naturezaOperacao: map['naturezaOperacao'] as String,
      idTransportadora: map['idTransportadora'] as String,
      fretePorConta: map['fretePorConta'] as String,
      placaDoVeiculo: map['placaDoVeiculo'] as String,
      ufDoVeiculo: map['ufDoVeiculo'] as String,
      quantidadeTrans: map['quantidadeTrans'] as String,
      especieTrans: map['especieTrans'] as String,
      marcaTrans: map['marcaTrans'] as String,
      numeracaoTrans: map['numeracaoTrans'] as String,
      pesoBrutoTrans: map['pesoBrutoTrans'] as String,
      pesoLiquidoTrans: map['pesoLiquidoTrans'] as String,
      idMedico: map['idMedico'] as String,
      tipoDeOpacaoSaida: map['tipoDeOpacaoSaida'] as String,
      tipoNfReferenciada: map['tipoNfReferenciada'] as String,
      chaveAcessoNfeRef: map['chaveAcessoNfeRef'] as String,
      stilo1: map['stilo1'] as String,
      stilo2: map['stilo2'] as String,
      stilo3: map['stilo3'] as String,
      ocultarReceberInscricao: map['ocultarReceberInscricao'] as String,
      numeroDoPedido: map['numeroDoPedido'] as String,
      nomeCliente: map['nomeCliente'] as String,
      numeroCartao: map['numeroCartao'] as String,
      nomeEntradaSaida: map['nomeEntradaSaida'] as String,
      formaDePagamento: map['formaDePagamento'] as String,
      separarPgto: map['separarPgto'] as String,
      idValeTroca: map['idValeTroca'] as String,
      valorTotalListar: map['valorTotalListar'] as String,
      nomeDoModelo: map['nomeDoModelo'] as String,
      numeroNotafiscal: map['numeroNotafiscal'] as String,
      statusSefaz: map['statusSefaz'] as String,
      ocultarEnvioDeComprovanteGerencial: map['ocultarEnvioDeComprovanteGerencial'] as String,
      desabilitarNfe: map['desabilitarNfe'] as String,
      ocultar: map['ocultar'] as String,
      desabilitarModuloNfe: map['desabilitarModuloNfe'] as String,
      ocultarCondicional: map['ocultarCondicional'] as String,
      titleCpfNota: map['titleCpfNota'] as String,
      desabilitarModuloNfce: map['desabilitarModuloNfce'] as String,
      desabilitarNfce: map['desabilitarNfce'] as String,
      ocultarCpfNaNota: map['ocultarCpfNaNota'] as String,
      temInformacao: map['temInformacao'] as String,
      ocultarEmissaoNfce: map['ocultarEmissaoNfce'] as String,
      habilitarCancelamentoNfe: map['habilitarCancelamentoNfe'] as String,
      habilitarCancelamentoNfce: map['habilitarCancelamentoNfce'] as String,
      ocultarWhatsapp: map['ocultarWhatsapp'] as String,
      ocultarOpcaoesDeEnvio: map['ocultarOpcaoesDeEnvio'] as String,
      ocultarEmailNota: map['ocultarEmailNota'] as String,
      titleFinalizar: map['titleFinalizar'] as String,
      mostrarOpcaoDeVenda: map['mostrarOpcaoDeVenda'] as String,
      ativoNotaNfe: map['ativoNotaNfe'] as String,
      desabilitarCartaDeCorrecao: map['desabilitarCartaDeCorrecao'] as String,
      desabilitarCartaNfeCancelada: map['desabilitarCartaNfeCancelada'] as String,
      celularCliente: map['celularCliente'] as String,
      emailCliente: map['emailCliente'] as String,
      nomeVendedor: map['nomeVendedor'] as String,
      valorDoDescontoF: map['valorDoDescontoF'] as String,
      qtdItensTabela: map['qtdItensTabela'] as String,
      quantProVenda: map['quantProVenda'] as String,
      tipoDeRelatorio: map['tipoDeRelatorio'] as String,
      desabilitarModuloFiscal: map['desabilitarModuloFiscal'] as String,
      ativarIcone: map['ativarIcone'] as String,
      corStatusSefaz: map['corStatusSefaz'] as String,
      stiloStatus1: map['stiloStatus1'] as String,
      stiloStatus2: map['stiloStatus2'] as String,
      stiloStatus3: map['stiloStatus3'] as String,
      ativoNotaNfce: map['ativoNotaNfce'] as String,
      valorTotalF: map['valorTotalF'] as String,
      tipodemodulo: map['tipodemodulo'] as String,
      docempresa: map['docempresa'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ListarVendasModelo.fromJson(String source) => ListarVendasModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
