// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class MesaModelo {
  final String id;
  final String codigo;
  final String nome;
  final bool mesaOcupada;
  String ativo;
  String? idCliente;
  String? nomeCliente;
  String? obs;
  String? dataAbertura;
  String? horaAbertura;
  String? idComandaPedido;
  String? valor;
  String? ultimaVezAbertoDataHora;
  String? dataultimopedido;
  bool? fechamento;

  MesaModelo({
    required this.id,
    required this.codigo,
    required this.nome,
    required this.mesaOcupada,
    required this.ativo,
    this.idCliente,
    required this.nomeCliente,
    this.obs,
    required this.dataAbertura,
    required this.horaAbertura,
    this.idComandaPedido,
    this.valor,
    this.ultimaVezAbertoDataHora,
    this.fechamento,
    this.dataultimopedido,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'codigo': codigo,
      'nome': nome,
      'mesaOcupada': mesaOcupada,
      'ativo': ativo,
      'idCliente': idCliente,
      'nomeCliente': nomeCliente,
      'obs': obs,
      'dataAbertura': dataAbertura,
      'horaAbertura': horaAbertura,
      'idComandaPedido': idComandaPedido,
      'valor': valor,
      'ultimaVezAbertoDataHora': ultimaVezAbertoDataHora,
      'dataultimopedido': dataultimopedido,
      'fechamento': fechamento,
    };
  }

  factory MesaModelo.fromMap(Map<String, dynamic> map) {
    return MesaModelo(
      id: map['id'] as String,
      codigo: map['codigo'] as String,
      nome: map['nome'] as String,
      mesaOcupada: map['mesaOcupada'] as bool,
      ativo: map['ativo'] as String,
      idCliente: map['idCliente'] != null ? map['idCliente'] as String : null,
      nomeCliente: map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      dataAbertura: map['dataAbertura'] != null ? map['dataAbertura'] as String : null,
      horaAbertura: map['horaAbertura'] != null ? map['horaAbertura'] as String : null,
      idComandaPedido: map['idComandaPedido'] != null ? map['idComandaPedido'] as String : null,
      valor: map['valor'] != null ? map['valor'] as String : null,
      ultimaVezAbertoDataHora: map['ultimaVezAbertoDataHora'] != null ? map['ultimaVezAbertoDataHora'] as String : null,
      dataultimopedido: map['dataultimopedido'] != null ? map['dataultimopedido'] as String : null,
      fechamento: map['fechamento'] != null ? map['fechamento'] as bool : null,
      obs: map['obs'] != null ? map['obs'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesaModelo.fromJson(String source) => MesaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
