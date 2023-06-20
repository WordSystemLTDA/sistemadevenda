// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class MesaModel {
  String id;
  String nome;
  bool mesaOcupada;
  MesaModel({
    required this.id,
    required this.nome,
    required this.mesaOcupada,
  });

  MesaModel copyWith({
    String? id,
    String? nome,
    bool? mesaOcupada,
  }) {
    return MesaModel(
      id: id ?? this.id,
      nome: nome ?? this.nome,
      mesaOcupada: mesaOcupada ?? this.mesaOcupada,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'nome': nome,
      'mesaOcupada': mesaOcupada,
    };
  }

  factory MesaModel.fromMap(Map<String, dynamic> map) {
    return MesaModel(
      id: map['id'] as String,
      nome: map['nome'] as String,
      mesaOcupada: map['mesaOcupada'] as bool,
    );
  }

  String toJson() => json.encode(toMap());

  factory MesaModel.fromJson(String source) => MesaModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'MesaModel(id: $id, nome: $nome, mesaOcupada: $mesaOcupada)';

  @override
  bool operator ==(covariant MesaModel other) {
    if (identical(this, other)) return true;

    return other.id == id && other.nome == nome && other.mesaOcupada == mesaOcupada;
  }

  @override
  int get hashCode => id.hashCode ^ nome.hashCode ^ mesaOcupada.hashCode;
}
