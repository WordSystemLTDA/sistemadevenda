import 'package:app/src/features/comandas/data/services/comanda_service_impl.dart';
import 'package:flutter/material.dart';

final ValueNotifier comandasState = ValueNotifier([]);

class ComandasState {
  final ComandaServiceImpl _service = ComandaServiceImpl();

  Future<void> listarComandas() async {
    final res = await _service.listar();
    comandasState.value = res;
  }

  Future<List<dynamic>> listarMesas(String pesquisa) async {
    return await _service.listarMesa(pesquisa);
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _service.listarClientes(pesquisa);
  }

  Future<dynamic> inserirComandaOcupada(String id, String idMesa, String idCliente, String obs) async {
    final res = await _service.inserirComandaOcupada(id, idMesa, idCliente, obs);
    if (res) {
      listarComandas();
    }
    return res;
  }

  Future<bool> inserirCliente(String nome, String celular, String email, String obs) async {
    final res = await _service.inserirCliente(nome, celular, email, obs);
    return res;
  }
}
