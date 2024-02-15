import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:flutter/material.dart';

final ValueNotifier listaMesaState = ValueNotifier([]);

class MesaState {
  final MesaServiceImpl _service = MesaServiceImpl();

  Future<void> listarMesas() async {
    final res = await _service.listar();
    listaMesaState.value = res;
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _service.listarClientes(pesquisa);
  }

  Future<bool> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
    final res = await _service.inserirMesaOcupada(idMesa, idCliente, obs);
    if (res) {
      listarMesas();
    }
    return res;
  }
}
