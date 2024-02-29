import 'dart:convert';

class ComandaModel {
  String id;
  String nome;
  String ativo;
  String nomeCliente;
  String nomeMesa;
  bool comandaOcupada;

  ComandaModel({
    required this.id,
    required this.nome,
    required this.ativo,
    required this.nomeCliente,
    required this.nomeMesa,
    required this.comandaOcupada,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'ativo': ativo,
      'nomeCliente': nomeCliente,
      'nomeMesa': nomeMesa,
      'comandaOcupada': comandaOcupada,
    };
  }

  factory ComandaModel.fromMap(Map<String, dynamic> map) {
    return ComandaModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      ativo: map['ativo'] as String,
      nomeCliente: map['nomeCliente'] as String,
      nomeMesa: map['nomeMesa'] as String,
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

