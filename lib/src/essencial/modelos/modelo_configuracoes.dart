import 'dart:convert';

class Modelowordconfiguracoes {
  final String empresa;
  final String habordemdeservico;
  final String habvendarepresentante;
  final String habdeliverymesa;
  final String habdeliverycomandas;
  final String habdeliverybalcao;
  final String habdelivery;
  final String habdeliverypreparacao;
  final String cartaoprepago;
  final String semvalorfinalizacao;
  final String? atalhopadraovenda;
  final String? tipodemodulo;
  final String? modelopadraopdv;
  final String? nomepadraoatendimento;
  final String? nomepadraoatendimentos;
  final String? nomepadraocliente;
  final String? nomepadraoclientes;
  final String? nomepadraoagenda;
  final String? nomepadraoconsulta;
  final String? horaInicio;
  final String? horaFim;
  final String? intervalo;
  final String? diasDaSemanaDisponiveis;
  final String? horaInicioTrabalho;
  final String? horaFimTrabalho;

  Modelowordconfiguracoes({
    required this.empresa,
    required this.habordemdeservico,
    required this.habvendarepresentante,
    required this.habdeliverymesa,
    required this.habdeliverycomandas,
    required this.habdeliverybalcao,
    required this.habdelivery,
    required this.habdeliverypreparacao,
    required this.cartaoprepago,
    required this.semvalorfinalizacao,
    this.atalhopadraovenda,
    this.tipodemodulo,
    this.modelopadraopdv,
    this.nomepadraoatendimento,
    this.nomepadraoatendimentos,
    this.nomepadraocliente,
    this.nomepadraoclientes,
    this.nomepadraoagenda,
    this.nomepadraoconsulta,
    this.horaInicio,
    this.horaFim,
    this.intervalo,
    this.diasDaSemanaDisponiveis,
    this.horaInicioTrabalho,
    this.horaFimTrabalho,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'empresa': empresa,
      'habordemdeservico': habordemdeservico,
      'habvendarepresentante': habvendarepresentante,
      'habdeliverymesa': habdeliverymesa,
      'habdeliverycomandas': habdeliverycomandas,
      'habdeliverybalcao': habdeliverybalcao,
      'habdelivery': habdelivery,
      'habdeliverypreparacao': habdeliverypreparacao,
      'cartaoprepago': cartaoprepago,
      'semvalorfinalizacao': semvalorfinalizacao,
      'atalhopadraovenda': atalhopadraovenda,
      'tipodemodulo': tipodemodulo,
      'modelopadraopdv': modelopadraopdv,
      'nomepadraoatendimento': nomepadraoatendimento,
      'nomepadraoatendimentos': nomepadraoatendimentos,
      'nomepadraocliente': nomepadraocliente,
      'nomepadraoclientes': nomepadraoclientes,
      'nomepadraoagenda': nomepadraoagenda,
      'nomepadraoconsulta': nomepadraoconsulta,
      'horaInicio': horaInicio,
      'horaFim': horaFim,
      'intervalo': intervalo,
      'diasDaSemanaDisponiveis': diasDaSemanaDisponiveis,
      'horaInicioTrabalho': horaInicioTrabalho,
      'horaFimTrabalho': horaFimTrabalho,
    };
  }

  factory Modelowordconfiguracoes.fromMap(Map<String, dynamic> map) {
    return Modelowordconfiguracoes(
      empresa: map['empresa'] as String,
      habordemdeservico: map['habordemdeservico'] as String,
      habvendarepresentante: map['habvendarepresentante'] as String,
      habdeliverymesa: map['habdeliverymesa'] as String,
      habdeliverycomandas: map['habdeliverycomandas'] as String,
      habdeliverybalcao: map['habdeliverybalcao'] as String,
      habdelivery: map['habdelivery'] as String,
      habdeliverypreparacao: map['habdeliverypreparacao'] as String,
      cartaoprepago: map['cartaoprepago'] as String,
      semvalorfinalizacao: map['semvalorfinalizacao'] as String,
      atalhopadraovenda: map['atalhopadraovenda'] != null ? map['atalhopadraovenda'] as String : null,
      tipodemodulo: map['tipodemodulo'] != null ? map['tipodemodulo'] as String : null,
      modelopadraopdv: map['modelopadraopdv'] != null ? map['modelopadraopdv'] as String : null,
      nomepadraoatendimento: map['nomepadraoatendimento'] != null ? map['nomepadraoatendimento'] as String : null,
      nomepadraoatendimentos: map['nomepadraoatendimentos'] != null ? map['nomepadraoatendimentos'] as String : null,
      nomepadraocliente: map['nomepadraocliente'] != null ? map['nomepadraocliente'] as String : null,
      nomepadraoclientes: map['nomepadraoclientes'] != null ? map['nomepadraoclientes'] as String : null,
      nomepadraoagenda: map['nomepadraoagenda'] != null ? map['nomepadraoagenda'] as String : null,
      nomepadraoconsulta: map['nomepadraoconsulta'] != null ? map['nomepadraoconsulta'] as String : null,
      horaInicio: map['horaInicio'] != null ? map['horaInicio'] as String : null,
      horaFim: map['horaFim'] != null ? map['horaFim'] as String : null,
      intervalo: map['intervalo'] != null ? map['intervalo'] as String : null,
      diasDaSemanaDisponiveis: map['diasDaSemanaDisponiveis'] != null ? map['diasDaSemanaDisponiveis'] as String : null,
      horaInicioTrabalho: map['horaInicioTrabalho'] != null ? map['horaInicioTrabalho'] as String : null,
      horaFimTrabalho: map['horaFimTrabalho'] != null ? map['horaFimTrabalho'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordconfiguracoes.fromJson(String source) => Modelowordconfiguracoes.fromMap(json.decode(source) as Map<String, dynamic>);
}
