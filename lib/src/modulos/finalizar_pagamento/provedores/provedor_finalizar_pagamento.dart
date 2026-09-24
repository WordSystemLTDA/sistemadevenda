import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:flutter/material.dart';

class ProvedorFinalizarPagamento extends ChangeNotifier {
  static const rotaRecebimentoObrigatorioDelivery =
      'PaginaRecebimentoObrigatorioDelivery';

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

  bool _recebimentoObrigatorioDelivery = false;
  bool get recebimentoObrigatorioDelivery => _recebimentoObrigatorioDelivery;
  String get rotaInicioFluxoDelivery => _recebimentoObrigatorioDelivery
      ? rotaRecebimentoObrigatorioDelivery
      : 'PaginaFinalizarAcrescimo';

  PedidoDelivery? _pedidoDelivery;
  PedidoDelivery? get pedidoDelivery => _pedidoDelivery;
  String? _ultimoEnderecoDelivery;
  String? get ultimoEnderecoDelivery => _ultimoEnderecoDelivery;

  void definirContextoDelivery({
    bool? recorrenteVinculado,
    bool pagamentoParcial = false,
    PedidoDelivery? pedido,
    bool recebimentoObrigatorio = false,
  }) {
    _deliveryRecorrenteVinculado = recorrenteVinculado;
    _deliveryComPagamentoParcial = pagamentoParcial;
    _pedidoDelivery = pedido;
    _recebimentoObrigatorioDelivery = recebimentoObrigatorio;
    _ultimoEnderecoDelivery =
        pedido?.tipoEntrega == '1' ? pedido?.texto('idendereco').trim() : null;
    notifyListeners();
  }

  void encerrarRecebimentoObrigatorioDelivery() {
    if (!_recebimentoObrigatorioDelivery) return;
    _recebimentoObrigatorioDelivery = false;
    notifyListeners();
  }

  void atualizarPedidoDelivery(PedidoDelivery pedido) {
    _pedidoDelivery = pedido;
    if (pedido.tipoEntrega == '1' &&
        pedido.texto('idendereco').trim().isNotEmpty &&
        pedido.texto('idendereco') != '0') {
      _ultimoEnderecoDelivery = pedido.texto('idendereco');
    }
    _valor = pedido.restante;
    notifyListeners();
  }
}
