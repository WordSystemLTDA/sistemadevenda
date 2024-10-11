// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class MesaModelo {
  final String id;
  final String nome;
  final bool mesaOcupada;
  final String ativo;
  String? nomeCliente;
  String? dataAbertura;
  String? horaAbertura;
  String? idComandaPedido;
  String? valor;

  MesaModelo({
    required this.id,
    required this.nome,
    required this.mesaOcupada,
    required this.ativo,
    required this.nomeCliente,
    required this.dataAbertura,
    required this.horaAbertura,
    this.idComandaPedido,
    this.valor,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'mesaOcupada': mesaOcupada,
      'ativo': ativo,
      'nomeCliente': nomeCliente,
      'dataAbertura': dataAbertura,
      'horaAbertura': horaAbertura,
      'idComandaPedido': idComandaPedido,
      'valor': valor,
    };
  }

  factory MesaModelo.fromMap(Map<String, dynamic> map) {
    return MesaModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      mesaOcupada: map['mesaOcupada'] as bool,
      ativo: map['ativo'] as String,
      nomeCliente: map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      dataAbertura: map['dataAbertura'] != null ? map['dataAbertura'] as String : null,
      horaAbertura: map['horaAbertura'] != null ? map['horaAbertura'] as String : null,
      idComandaPedido: map['idComandaPedido'] != null ? map['idComandaPedido'] as String : null,
      valor: map['valor'] != null ? map['valor'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesaModelo.fromJson(String source) => MesaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
