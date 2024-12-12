import 'dart:convert';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class ConfigModelo {
  String versaoAppAndroid;
  String versaoAppIos;
  String linkAtualizacaoAndroid;
  String linkAtualizacaoIos;
  String linkBaixarApk;
  String nomeApp;
  String anoApp;
  String logoApp;

  ConfigModelo({
    required this.versaoAppAndroid,
    required this.versaoAppIos,
    required this.linkAtualizacaoAndroid,
    required this.linkAtualizacaoIos,
    required this.linkBaixarApk,
    required this.nomeApp,
    required this.anoApp,
    required this.logoApp,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'versaoAppAndroid': versaoAppAndroid,
      'versaoAppIos': versaoAppIos,
      'linkAtualizacaoAndroid': linkAtualizacaoAndroid,
      'linkAtualizacaoIos': linkAtualizacaoIos,
      'linkBaixarApk': linkBaixarApk,
      'nomeApp': nomeApp,
      'anoApp': anoApp,
      'logoApp': logoApp,
    };
  }

  factory ConfigModelo.fromMap(Map<String, dynamic> map) {
    return ConfigModelo(
      versaoAppAndroid: map['versaoAppAndroid'] as String,
      versaoAppIos: map['versaoAppIos'] as String,
      linkAtualizacaoAndroid: map['linkAtualizacaoAndroid'] as String,
      linkAtualizacaoIos: map['linkAtualizacaoIos'] as String,
      linkBaixarApk: map['linkBaixarApk'] as String,
      nomeApp: map['nomeApp'] as String,
      anoApp: map['anoApp'] as String,
      logoApp: map['logoApp'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ConfigModelo.fromJson(String source) => ConfigModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
