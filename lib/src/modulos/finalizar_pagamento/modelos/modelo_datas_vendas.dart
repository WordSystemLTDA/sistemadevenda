// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

class ModeloDatasVendas {
  static const String dia1Padrao = '30';
  static const String dia2Padrao = '45';
  static const String dia3Padrao = '60';
  static const String dia4Padrao = '90';

  final String vendaDia1;
  final String vendaDia2;
  final String vendaDia3;
  final String vendaDia4;

  ModeloDatasVendas({
    required this.vendaDia1,
    required this.vendaDia2,
    required this.vendaDia3,
    required this.vendaDia4,
  });

  factory ModeloDatasVendas.padrao() => ModeloDatasVendas(
        vendaDia1: dia1Padrao,
        vendaDia2: dia2Padrao,
        vendaDia3: dia3Padrao,
        vendaDia4: dia4Padrao,
      );

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'vendaDia1': vendaDia1,
      'vendaDia2': vendaDia2,
      'vendaDia3': vendaDia3,
      'vendaDia4': vendaDia4,
    };
  }

  factory ModeloDatasVendas.fromMap(Map<String, dynamic> map) {
    return ModeloDatasVendas(
      vendaDia1:
          _normalizarDia(map['vendaDia1'] ?? map['venda_dia1'], dia1Padrao),
      vendaDia2:
          _normalizarDia(map['vendaDia2'] ?? map['venda_dia2'], dia2Padrao),
      vendaDia3:
          _normalizarDia(map['vendaDia3'] ?? map['venda_dia3'], dia3Padrao),
      vendaDia4:
          _normalizarDia(map['vendaDia4'] ?? map['venda_dia4'], dia4Padrao),
    );
  }

  static String _normalizarDia(Object? valor, String padrao) {
    final dias = int.tryParse(valor?.toString().trim() ?? '');
    return dias != null && dias >= 0 ? dias.toString() : padrao;
  }

  String toJson() => json.encode(toMap());

  factory ModeloDatasVendas.fromJson(String source) =>
      ModeloDatasVendas.fromMap(json.decode(source) as Map<String, dynamic>);
}
