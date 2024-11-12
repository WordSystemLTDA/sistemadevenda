import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/services.dart';

class ConstantesGlobal {
  static var mascaraRG = [
    FilteringTextInputFormatter.digitsOnly,
    // RgInputFormatter(), // CRIADO LOCALMENTE
  ];

  static var mascaraCEP = [
    FilteringTextInputFormatter.digitsOnly,
    CepInputFormatter(),
  ];

  static var mascaraCPF = [
    FilteringTextInputFormatter.digitsOnly,
    CpfInputFormatter(),
  ];

  static var mascaraCNPJ = [
    FilteringTextInputFormatter.digitsOnly,
    CnpjInputFormatter(),
  ];

  static var mascaraCpfOuCnpj = [
    FilteringTextInputFormatter.digitsOnly,
    CpfOuCnpjFormatter(),
  ];

  static var mascaraCelularTelefone = [
    FilteringTextInputFormatter.digitsOnly,
    TelefoneInputFormatter(),
  ];
}
