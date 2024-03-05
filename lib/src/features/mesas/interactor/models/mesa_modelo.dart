import 'dart:convert';

class MesaModelo {
  final String id;
  final String nome;
  final String nomeCliente;
  final String dataAbertura;
  final String horaAbertura;
  final String ativo;
  final bool mesaOcupada;

  MesaModelo({
    required this.id,
    required this.nome,
    required this.nomeCliente,
    required this.dataAbertura,
    required this.horaAbertura,
    required this.ativo,
    required this.mesaOcupada,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'nomeCliente': nomeCliente,
      'dataAbertura': dataAbertura,
      'horaAbertura': horaAbertura,
      'ativo': ativo,
      'mesaOcupada': mesaOcupada,
    };
  }

  factory MesaModelo.fromMap(Map<String, dynamic> map) {
    return MesaModelo(
      id: map['id'] as String,
      nome: map['nome'] as String,
      nomeCliente: map['nomeCliente'] as String,
      dataAbertura: map['dataAbertura'] as String,
      horaAbertura: map['horaAbertura'] as String,
      ativo: map['ativo'] as String,
      mesaOcupada: map['mesaOcupada'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesaModelo.fromJson(String source) => MesaModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
