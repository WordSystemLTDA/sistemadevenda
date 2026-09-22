import 'package:app/src/essencial/api/socket/eventos_catalogo.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AtualizacaoDeTela {
  void call(ModeloRetornoSocket dados) {
    EventosCatalogo.notificar(dados.tipo);
    final tipo = dados.tipo.trim().toLowerCase();
    if (tipo == 'mesa') {
      Modular.tryGet<ProvedorMesas>()?.listarMesas('', mostrarCarregamento: false);
    } else if (tipo == 'comanda') {
      Modular.tryGet<ProvedorComanda>()?.listarComandas('', mostrarCarregamento: false);
    } else if (tipo == 'balcao' || tipo == 'balc\u00e3o') {
      Modular.tryGet<ProvedorBalcao>()?.listar();
    } else if (tipo == 'delivery') {
      Modular.tryGet<ProvedorDelivery>()?.listar(mostrarCarregamento: false);
    }
  }
}
