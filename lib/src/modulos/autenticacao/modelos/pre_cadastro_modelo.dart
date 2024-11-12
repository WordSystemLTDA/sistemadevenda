import 'dart:convert';

class PreCadastroModelo {
  final String razaoSocial;
  final String nome;
  final String tipoPessoa;
  final String doc;
  final String incEst;
  final String email;
  final String celular;
  final String cep;
  final String endereco;
  final String numero;
  final String bairro;
  final String complemento;
  final String cidade;

  PreCadastroModelo({
    required this.razaoSocial,
    required this.nome,
    required this.tipoPessoa,
    required this.doc,
    required this.incEst,
    required this.email,
    required this.celular,
    required this.cep,
    required this.endereco,
    required this.numero,
    required this.bairro,
    required this.complemento,
    required this.cidade,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'razaoSocial': razaoSocial,
      'nome': nome,
      'tipoPessoa': tipoPessoa,
      'doc': doc,
      'incEst': incEst,
      'email': email,
      'celular': celular,
      'cep': cep,
      'endereco': endereco,
      'numero': numero,
      'bairro': bairro,
      'complemento': complemento,
      'cidade': cidade,
    };
  }

  factory PreCadastroModelo.fromMap(Map<String, dynamic> map) {
    return PreCadastroModelo(
      razaoSocial: map['razaoSocial'] as String,
      nome: map['nome'] as String,
      tipoPessoa: map['tipoPessoa'] as String,
      doc: map['doc'] as String,
      incEst: map['incEst'] as String,
      email: map['email'] as String,
      celular: map['celular'] as String,
      cep: map['cep'] as String,
      endereco: map['endereco'] as String,
      numero: map['numero'] as String,
      bairro: map['bairro'] as String,
      complemento: map['complemento'] as String,
      cidade: map['cidade'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory PreCadastroModelo.fromJson(String source) => PreCadastroModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
