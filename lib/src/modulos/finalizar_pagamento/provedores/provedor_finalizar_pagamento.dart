import 'package:flutter/material.dart';

class ProvedorFinalizarPagamento extends ChangeNotifier {
  String _idVenda = '0';
  String get idVenda => _idVenda;
  set idVenda(String value) {
    _idVenda = value;
    notifyListeners();
  }

  double _valor = 0;
  double get valor => _valor;
  set valor(double value) {
    _valor = value;
    notifyListeners();
  }

  bool? _deliveryRecorrenteVinculado;
  bool? get deliveryRecorrenteVinculado => _deliveryRecorrenteVinculado;
  String get rotaRetornoDelivery => _deliveryRecorrenteVinculado == true
      ? 'PaginaRecorrentes'
      : 'PaginaDelivery';

  bool _deliveryComPagamentoParcial = false;
  bool get deliveryComPagamentoParcial => _deliveryComPagamentoParcial;

  void definirContextoDelivery({
    bool? recorrenteVinculado,
    bool pagamentoParcial = false,
  }) {
    _deliveryRecorrenteVinculado = recorrenteVinculado;
    _deliveryComPagamentoParcial = pagamentoParcial;
    notifyListeners();
  }
}
