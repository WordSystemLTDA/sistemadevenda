// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloConfigBigchef {
  final String abrircomandadireto;
  final String abrirmesadireto;
  final String agrupamentodeitenscomanda;
  final String agrupamentodeitensmesa;
  final String obrigarjustifcancelarpedido;
  final String mostrarnomeempresapreparo;
  final String mostrarnomeclientepreparo;
  final String tamanhofontepreparoaltura;
  final String tamanhofontepreparolargura;
  final String formacobrancaentregadelivery;
  final String valordaentrega;

  ModeloConfigBigchef({
    required this.abrircomandadireto,
    required this.abrirmesadireto,
    required this.agrupamentodeitenscomanda,
    required this.agrupamentodeitensmesa,
    required this.obrigarjustifcancelarpedido,
    required this.mostrarnomeempresapreparo,
    required this.mostrarnomeclientepreparo,
    required this.tamanhofontepreparoaltura,
    required this.tamanhofontepreparolargura,
    required this.formacobrancaentregadelivery,
    required this.valordaentrega,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'abrircomandadireto': abrircomandadireto,
      'abrirmesadireto': abrirmesadireto,
      'agrupamentodeitenscomanda': agrupamentodeitenscomanda,
      'agrupamentodeitensmesa': agrupamentodeitensmesa,
      'obrigarjustifcancelarpedido': obrigarjustifcancelarpedido,
      'mostrarnomeempresapreparo': mostrarnomeempresapreparo,
      'mostrarnomeclientepreparo': mostrarnomeclientepreparo,
      'tamanhofontepreparoaltura': tamanhofontepreparoaltura,
      'tamanhofontepreparolargura': tamanhofontepreparolargura,
      'formacobrancaentregadelivery': formacobrancaentregadelivery,
      'valordaentrega': valordaentrega,
    };
  }

  factory ModeloConfigBigchef.fromMap(Map<String, dynamic> map) {
    return ModeloConfigBigchef(
      abrircomandadireto: map['abrircomandadireto'] as String,
      abrirmesadireto: map['abrirmesadireto'] as String,
      agrupamentodeitenscomanda: map['agrupamentodeitenscomanda'] as String,
      agrupamentodeitensmesa: map['agrupamentodeitensmesa'] as String,
      obrigarjustifcancelarpedido: map['obrigarjustifcancelarpedido'] as String,
      mostrarnomeempresapreparo: map['mostrarnomeempresapreparo'] as String,
      mostrarnomeclientepreparo: map['mostrarnomeclientepreparo'] as String,
      tamanhofontepreparoaltura: map['tamanhofontepreparoaltura'] as String,
      tamanhofontepreparolargura: map['tamanhofontepreparolargura'] as String,
      formacobrancaentregadelivery: map['formacobrancaentregadelivery'] as String,
      valordaentrega: map['valordaentrega'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ModeloConfigBigchef.fromJson(String source) => ModeloConfigBigchef.fromMap(json.decode(source) as Map<String, dynamic>);
}
