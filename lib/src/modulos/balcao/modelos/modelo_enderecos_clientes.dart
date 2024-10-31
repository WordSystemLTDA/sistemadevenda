// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class Modelowordenderecosclientes {
  final String id;
  final String endereco;
  final String cep;
  final String numero;
  final String complemento;
  final String padrao;
  final String bairro;
  final String cidade;
  final int tamanhoLista;

  Modelowordenderecosclientes({
    required this.id,
    required this.endereco,
    required this.cep,
    required this.numero,
    required this.complemento,
    required this.padrao,
    required this.bairro,
    required this.cidade,
    required this.tamanhoLista,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'endereco': endereco,
      'cep': cep,
      'numero': numero,
      'complemento': complemento,
      'padrao': padrao,
      'bairro': bairro,
      'cidade': cidade,
      'tamanhoLista': tamanhoLista,
    };
  }

  factory Modelowordenderecosclientes.fromMap(Map<String, dynamic> map) {
    return Modelowordenderecosclientes(
      id: map['id'] as String,
      endereco: map['endereco'] as String,
      cep: map['cep'] as String,
      numero: map['numero'] as String,
      complemento: map['complemento'] as String,
      padrao: map['padrao'] as String,
      bairro: map['bairro'] as String,
      cidade: map['cidade'] as String,
      tamanhoLista: map['tamanhoLista'] as int,
    );
  }

  String toJson() => json.encode(toMap());

  factory Modelowordenderecosclientes.fromJson(String source) => Modelowordenderecosclientes.fromMap(json.decode(source) as Map<String, dynamic>);
}
