// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloComanda {
  String id;
  String nome;
  String codigo;
  String ativo;
  bool comandaOcupada;
  String? idCliente;
  String? nomeCliente;
  String? obs;
  String? nomeMesa;
  String? idmesa;
  String? dataAbertura;
  String? horaAbertura;
  String? dataultimopedido;
  String? idComandaPedido;
  String? valor;
  String? ultimaVezAbertoDataHora;
  bool? fechamento;

  ModeloComanda({
    required this.id,
    required this.nome,
    required this.codigo,
    required this.ativo,
    required this.comandaOcupada,
    this.idCliente,
    this.nomeCliente,
    this.obs,
    this.nomeMesa,
    this.idmesa,
    this.dataAbertura,
    this.horaAbertura,
    this.dataultimopedido,
    this.idComandaPedido,
    this.valor,
    this.ultimaVezAbertoDataHora,
    this.fechamento,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'codigo': codigo,
      'ativo': ativo,
      'comandaOcupada': comandaOcupada,
      'idCliente': idCliente,
      'nomeCliente': nomeCliente,
      'obs': obs,
      'nomeMesa': nomeMesa,
      'idmesa': idmesa,
      'dataAbertura': dataAbertura,
      'horaAbertura': horaAbertura,
      'dataultimopedido': dataultimopedido,
      'idComandaPedido': idComandaPedido,
      'valor': valor,
      'ultimaVezAbertoDataHora': ultimaVezAbertoDataHora,
      'fechamento': fechamento,
    };
  }

  factory ModeloComanda.fromMap(Map<String, dynamic> map) {
    return ModeloComanda(
      id: map['id'] as String,
      nome: map['nome'] as String,
      codigo: map['codigo'] as String,
      ativo: map['ativo'] as String,
      comandaOcupada: map['comandaOcupada'] as bool,
      idCliente: map['idCliente'] != null ? map['idCliente'] as String : null,
      nomeCliente: map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      obs: map['obs'] != null ? map['obs'] as String : null,
      nomeMesa: map['nomeMesa'] != null ? map['nomeMesa'] as String : null,
      idmesa: map['idmesa'] != null ? map['idmesa'] as String : null,
      dataAbertura: map['dataAbertura'] != null ? map['dataAbertura'] as String : null,
      horaAbertura: map['horaAbertura'] != null ? map['horaAbertura'] as String : null,
      dataultimopedido: map['dataultimopedido'] != null ? map['dataultimopedido'] as String : null,
      idComandaPedido: map['idComandaPedido'] != null ? map['idComandaPedido'] as String : null,
      valor: map['valor'] != null ? map['valor'] as String : null,
      ultimaVezAbertoDataHora: map['ultimaVezAbertoDataHora'] != null ? map['ultimaVezAbertoDataHora'] as String : null,
      fechamento: map['fechamento'] != null ? map['fechamento'] as bool : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloComanda.fromJson(String source) => ModeloComanda.fromMap(json.decode(source) as Map<String, dynamic>);
}



// import 'dart:convert';

// class ModeloComanda {
//   String id;
//   String nome;
//   bool comandaOcupada;

//   ModeloComanda({
//     required this.id,
//     required this.nome,
//     required this.comandaOcupada,
//   });

//   Map<String, dynamic> toMap() {
//     return <String, dynamic>{
//       'id': id,
//       'nome': nome,
//       'comandaOcupada': comandaOcupada,
//     };
//   }

//   factory ModeloComanda.fromMap(Map<String, dynamic> map) {
//     return ModeloComanda(
//       id: map['id'] as String,
//       nome: map['nome'] as String,
//       comandaOcupada: map['comandaOcupada'] as bool,
//     );
//   }

//   String toJson() => json.encode(toMap());

//   factory ModeloComanda.fromJson(String source) => ModeloComanda.fromMap(json.decode(source) as Map<String, dynamic>);
// }

