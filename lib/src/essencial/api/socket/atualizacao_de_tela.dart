import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AtualizacaoDeTela {
  void call(ModeloRetornoSocket dados) {
    if (dados.tipo == 'Mesa') {
      Modular.get<ProvedorMesas>().listarMesas('');
    } else if (dados.tipo == 'Comanda') {
      Modular.get<ProvedorComanda>().listarComandas('');
    } else if (dados.tipo == 'Balcão') {
      Modular.get<ProvedorBalcao>().listar();
    }
  }
}
