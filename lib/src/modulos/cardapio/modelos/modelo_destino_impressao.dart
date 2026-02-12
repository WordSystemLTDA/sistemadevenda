// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloDestinoImpressao {
  final String nome;
  final String nomeDaImpressora;
  final String tamanhoDoPapel;
  final String? avancoPapel;
  final String? nomedopc;

  ModeloDestinoImpressao({
    required this.nome,
    required this.nomeDaImpressora,
    required this.tamanhoDoPapel,
    this.avancoPapel,
    this.nomedopc,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'nome': nome,
      'nomeDaImpressora': nomeDaImpressora,
      'tamanhoDoPapel': tamanhoDoPapel,
      'avancoPapel': avancoPapel,
      'nomedopc': nomedopc,
    };
  }

  factory ModeloDestinoImpressao.fromMap(Map<String, dynamic> map) {
    return ModeloDestinoImpressao(
      nome: map['nome'] as String,
      nomeDaImpressora: map['nomeDaImpressora'] as String,
      tamanhoDoPapel: map['tamanhoDoPapel'] as String,
      avancoPapel:
          map['avancoPapel'] != null ? map['avancoPapel'] as String : null,
      nomedopc: map['nomedopc'] != null ? map['nomedopc'] as String : null,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDestinoImpressao.fromJson(String source) =>
      ModeloDestinoImpressao.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
