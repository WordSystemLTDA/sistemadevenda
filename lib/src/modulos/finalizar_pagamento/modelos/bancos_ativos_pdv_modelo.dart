// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class BancosAtivosPdvModelo {
  final String idBancoPix;
  final String idBancoOpcao2;
  final String idBancoOpcao3;
  final String idBancoOpcao4;
  final String idBancoOpcao5;

  final String ativoBancoPix;
  final String ativoBancoOpcao2;
  final String ativoBancoOpcao3;
  final String ativoBancoOpcao4;
  final String ativoBancoOpcao5;
  final String nomeBancoPix;
  final String nomeBancoOpcao2;
  final String nomeBancoOpcao3;
  final String nomeBancoOpcao4;
  final String nomeBancoOpcao5;
  final String pixdinamicopix;
  final String pixdinamicoopcao2;
  final String pixdinamicoopcao3;
  final String pixdinamicoopcao4;
  final String pixdinamicoopcao5;

  BancosAtivosPdvModelo({
    required this.idBancoPix,
    required this.idBancoOpcao2,
    required this.idBancoOpcao3,
    required this.idBancoOpcao4,
    required this.idBancoOpcao5,
    required this.ativoBancoPix,
    required this.ativoBancoOpcao2,
    required this.ativoBancoOpcao3,
    required this.ativoBancoOpcao4,
    required this.ativoBancoOpcao5,
    required this.nomeBancoPix,
    required this.nomeBancoOpcao2,
    required this.nomeBancoOpcao3,
    required this.nomeBancoOpcao4,
    required this.nomeBancoOpcao5,
    required this.pixdinamicopix,
    required this.pixdinamicoopcao2,
    required this.pixdinamicoopcao3,
    required this.pixdinamicoopcao4,
    required this.pixdinamicoopcao5,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'idBancoPix': idBancoPix,
      'idBancoOpcao2': idBancoOpcao2,
      'idBancoOpcao3': idBancoOpcao3,
      'idBancoOpcao4': idBancoOpcao4,
      'idBancoOpcao5': idBancoOpcao5,
      'ativoBancoPix': ativoBancoPix,
      'ativoBancoOpcao2': ativoBancoOpcao2,
      'ativoBancoOpcao3': ativoBancoOpcao3,
      'ativoBancoOpcao4': ativoBancoOpcao4,
      'ativoBancoOpcao5': ativoBancoOpcao5,
      'nomeBancoPix': nomeBancoPix,
      'nomeBancoOpcao2': nomeBancoOpcao2,
      'nomeBancoOpcao3': nomeBancoOpcao3,
      'nomeBancoOpcao4': nomeBancoOpcao4,
      'nomeBancoOpcao5': nomeBancoOpcao5,
      'pixdinamicopix': pixdinamicopix,
      'pixdinamicoopcao2': pixdinamicoopcao2,
      'pixdinamicoopcao3': pixdinamicoopcao3,
      'pixdinamicoopcao4': pixdinamicoopcao4,
      'pixdinamicoopcao5': pixdinamicoopcao5,
    };
  }

  factory BancosAtivosPdvModelo.fromMap(Map<String, dynamic> map) {
    return BancosAtivosPdvModelo(
      idBancoPix: map['idBancoPix'] as String,
      idBancoOpcao2: map['idBancoOpcao2'] as String,
      idBancoOpcao3: map['idBancoOpcao3'] as String,
      idBancoOpcao4: map['idBancoOpcao4'] as String,
      idBancoOpcao5: map['idBancoOpcao5'] as String,
      ativoBancoPix: map['ativoBancoPix'] as String,
      ativoBancoOpcao2: map['ativoBancoOpcao2'] as String,
      ativoBancoOpcao3: map['ativoBancoOpcao3'] as String,
      ativoBancoOpcao4: map['ativoBancoOpcao4'] as String,
      ativoBancoOpcao5: map['ativoBancoOpcao5'] as String,
      nomeBancoPix: map['nomeBancoPix'] as String,
      nomeBancoOpcao2: map['nomeBancoOpcao2'] as String,
      nomeBancoOpcao3: map['nomeBancoOpcao3'] as String,
      nomeBancoOpcao4: map['nomeBancoOpcao4'] as String,
      nomeBancoOpcao5: map['nomeBancoOpcao5'] as String,
      pixdinamicopix: map['pixdinamicopix'] as String,
      pixdinamicoopcao2: map['pixdinamicoopcao2'] as String,
      pixdinamicoopcao3: map['pixdinamicoopcao3'] as String,
      pixdinamicoopcao4: map['pixdinamicoopcao4'] as String,
      pixdinamicoopcao5: map['pixdinamicoopcao5'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory BancosAtivosPdvModelo.fromJson(String source) => BancosAtivosPdvModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
