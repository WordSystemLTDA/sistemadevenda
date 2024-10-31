import 'dart:convert';

class SalvarVendasModelo {
  final String id;
  final String cliente;
  final String nomeCliente;
  final String natureza;
  final String nomeNatureza;
  final String vendedor;
  final String nomeVendedor;
  final String dataLancamento;
  final String transportadora;
  final String nomeTransportadora;
  final String fretePorConta;
  final String nomeFretePorConta;
  final String placaDoVeiculo;
  final String uf;
  final String quantidade;
  final String especie;
  final String marca;
  final String numeracao;
  final String pesoBruto;
  final String pesoLiquido;
  final String tipoReferencia;
  final String nomeTipoReferencia;
  final String chaveAcesso;
  final String observacoesInterna;
  final String dadosAdicionais;

  SalvarVendasModelo({
    required this.id,
    required this.cliente,
    required this.nomeCliente,
    required this.natureza,
    required this.nomeNatureza,
    required this.vendedor,
    required this.nomeVendedor,
    required this.dataLancamento,
    required this.transportadora,
    required this.nomeTransportadora,
    required this.fretePorConta,
    required this.nomeFretePorConta,
    required this.placaDoVeiculo,
    required this.uf,
    required this.quantidade,
    required this.especie,
    required this.marca,
    required this.numeracao,
    required this.pesoBruto,
    required this.pesoLiquido,
    required this.tipoReferencia,
    required this.nomeTipoReferencia,
    required this.chaveAcesso,
    required this.observacoesInterna,
    required this.dadosAdicionais,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'cliente': cliente,
      'nomeCliente': nomeCliente,
      'natureza': natureza,
      'nomeNatureza': nomeNatureza,
      'vendedor': vendedor,
      'nomeVendedor': nomeVendedor,
      'dataLancamento': dataLancamento,
      'transportadora': transportadora,
      'nomeTransportadora': nomeTransportadora,
      'fretePorConta': fretePorConta,
      'nomeFretePorConta': nomeFretePorConta,
      'placaDoVeiculo': placaDoVeiculo,
      'uf': uf,
      'quantidade': quantidade,
      'especie': especie,
      'marca': marca,
      'numeracao': numeracao,
      'pesoBruto': pesoBruto,
      'pesoLiquido': pesoLiquido,
      'tipoReferencia': tipoReferencia,
      'nomeTipoReferencia': nomeTipoReferencia,
      'chaveAcesso': chaveAcesso,
      'observacoesInterna': observacoesInterna,
      'dadosAdicionais': dadosAdicionais,
    };
  }

  factory SalvarVendasModelo.fromMap(Map<String, dynamic> map) {
    return SalvarVendasModelo(
      id: map['id'] as String,
      cliente: map['cliente'] as String,
      nomeCliente: map['nomeCliente'] as String,
      natureza: map['natureza'] as String,
      nomeNatureza: map['nomeNatureza'] as String,
      vendedor: map['vendedor'] as String,
      nomeVendedor: map['nomeVendedor'] as String,
      dataLancamento: map['dataLancamento'] as String,
      transportadora: map['transportadora'] as String,
      nomeTransportadora: map['nomeTransportadora'] as String,
      fretePorConta: map['fretePorConta'] as String,
      nomeFretePorConta: map['nomeFretePorConta'] as String,
      placaDoVeiculo: map['placaDoVeiculo'] as String,
      uf: map['uf'] as String,
      quantidade: map['quantidade'] as String,
      especie: map['especie'] as String,
      marca: map['marca'] as String,
      numeracao: map['numeracao'] as String,
      pesoBruto: map['pesoBruto'] as String,
      pesoLiquido: map['pesoLiquido'] as String,
      tipoReferencia: map['tipoReferencia'] as String,
      nomeTipoReferencia: map['nomeTipoReferencia'] as String,
      chaveAcesso: map['chaveAcesso'] as String,
      observacoesInterna: map['observacoesInterna'] as String,
      dadosAdicionais: map['dadosAdicionais'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory SalvarVendasModelo.fromJson(String source) => SalvarVendasModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
