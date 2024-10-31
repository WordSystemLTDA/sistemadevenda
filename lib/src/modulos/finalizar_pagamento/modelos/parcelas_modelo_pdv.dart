import 'dart:convert';

import 'package:flutter/cupertino.dart';

// ignore_for_file: public_member_api_docs, sort_constructors_first
class ParcelasModelo {
  final String parcela;
  final String valor;
  final String vencimento;
  TextEditingController? valorController;
  TextEditingController? vencimentoController;

  ParcelasModelo({
    required this.parcela,
    required this.valor,
    required this.vencimento,
    this.valorController,
    this.vencimentoController,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'parcela': parcela,
      'valor': valor,
      'vencimento': vencimento,
      'valorController': valorController,
      'vencimentoController': vencimentoController,
    };
  }

  factory ParcelasModelo.fromMap(Map<String, dynamic> map) {
    return ParcelasModelo(
      parcela: map['parcela'] as String,
      valor: map['valor'] as String,
      vencimento: map['vencimento'] as String,
      valorController: map['valorController'] as TextEditingController,
      vencimentoController: map['vencimentoController'] as TextEditingController,
    );
  }

  String toJson() => json.encode(toMap());

  factory ParcelasModelo.fromJson(String source) => ParcelasModelo.fromMap(json.decode(source) as Map<String, dynamic>);
}
