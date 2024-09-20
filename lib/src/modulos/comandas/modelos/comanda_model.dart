// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ComandaModel {
  String id;
  String idComandaPedido;
  String nome;
  String ativo;
  String nomeCliente;
  String nomeMesa;
  String dataAbertura;
  String horaAbertura;
  bool comandaOcupada;

  ComandaModel({
    required this.id,
    required this.idComandaPedido,
    required this.nome,
    required this.ativo,
    required this.nomeCliente,
    required this.nomeMesa,
    required this.dataAbertura,
    required this.horaAbertura,
    required this.comandaOcupada,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'idComandaPedido': idComandaPedido,
      'nome': nome,
      'ativo': ativo,
      'nomeCliente': nomeCliente,
      'nomeMesa': nomeMesa,
      'dataAbertura': dataAbertura,
      'horaAbertura': horaAbertura,
      'comandaOcupada': comandaOcupada,
    };
  }

  factory ComandaModel.fromMap(Map<String, dynamic> map) {
    return ComandaModel(
      id: map['id'] as String,
      idComandaPedido: map['idComandaPedido'] as String,
      nome: map['nome'] as String,
      ativo: map['ativo'] as String,
      nomeCliente: map['nomeCliente'] as String,
      nomeMesa: map['nomeMesa'] as String,
      dataAbertura: map['dataAbertura'] as String,
      horaAbertura: map['horaAbertura'] as String,
      comandaOcupada: map['comandaOcupada'] as bool,
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

