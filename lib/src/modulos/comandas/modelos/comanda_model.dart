// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ComandaModel {
  String id;
  String nome;
  String ativo;
  bool comandaOcupada;
  String? nomeCliente;
  String? nomeMesa;
  String? dataAbertura;
  String? horaAbertura;
  String? idComandaPedido;
  String? valor;

  ComandaModel({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.comandaOcupada,
    this.nomeCliente,
    this.nomeMesa,
    this.dataAbertura,
    this.horaAbertura,
    this.idComandaPedido,
    this.valor,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'ativo': ativo,
      'comandaOcupada': comandaOcupada,
      'nomeCliente': nomeCliente,
      'nomeMesa': nomeMesa,
      'dataAbertura': dataAbertura,
      'horaAbertura': horaAbertura,
      'idComandaPedido': idComandaPedido,
      'valor': valor,
    };
  }

  factory ComandaModel.fromMap(Map<String, dynamic> map) {
    return ComandaModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      ativo: map['ativo'] as String,
      comandaOcupada: map['comandaOcupada'] as bool,
      nomeCliente: map['nomeCliente'] != null ? map['nomeCliente'] as String : null,
      nomeMesa: map['nomeMesa'] != null ? map['nomeMesa'] as String : null,
      dataAbertura: map['dataAbertura'] != null ? map['dataAbertura'] as String : null,
      horaAbertura: map['horaAbertura'] != null ? map['horaAbertura'] as String : null,
      idComandaPedido: map['idComandaPedido'] != null ? map['idComandaPedido'] as String : null,
      valor: map['valor'] != null ? map['valor'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ComandaModel.fromJson(String source) => ComandaModel.fromMap(json.decode(source) as Map<String, dynamic>);
}



// import 'dart:convert';

// class ComandaModel {
//   String id;
//   String nome;
//   bool comandaOcupada;

//   ComandaModel({
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

//   factory ComandaModel.fromMap(Map<String, dynamic> map) {
//     return ComandaModel(
//       id: map['id'] as String,
//       nome: map['nome'] as String,
//       comandaOcupada: map['comandaOcupada'] as bool,
//     );
//   }

//   String toJson() => json.encode(toMap());

//   factory ComandaModel.fromJson(String source) => ComandaModel.fromMap(json.decode(source) as Map<String, dynamic>);
// }

