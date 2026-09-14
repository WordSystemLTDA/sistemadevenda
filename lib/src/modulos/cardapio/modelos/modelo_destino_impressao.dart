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
      nome: map['nome']?.toString() ?? '',
      nomeDaImpressora: map['nomeDaImpressora']?.toString() ?? '',
      tamanhoDoPapel: map['tamanhoDoPapel']?.toString() ?? '',
      avancoPapel: map['avancoPapel']?.toString(),
      nomedopc: map['nomedopc']?.toString(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloDestinoImpressao.fromJson(String source) =>
      ModeloDestinoImpressao.fromMap(
          json.decode(source) as Map<String, dynamic>);
}
