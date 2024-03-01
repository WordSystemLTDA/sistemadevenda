import 'package:app/src/features/comandas/data/services/comanda_service_impl.dart';
import 'package:flutter/material.dart';

final ValueNotifier comandasState = ValueNotifier([]);

class ComandasState {
  final ComandaServiceImpl _service = ComandaServiceImpl();

  Future<void> listarComandas(String pesquisa) async {
    final res = await _service.listar(pesquisa);
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
      listarComandas('');
    }
    return res;
  }

  Future<bool> inserirCliente(String nome, String celular, String email, String obs) async {
    return await _service.inserirCliente(nome, celular, email, obs);
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final res = await _service.editarAtivo(id, ativo);
    listarComandas('');
    return res;
  }

  Future<Map<String, dynamic>> excluirComanda(String id) async {
    final res = await _service.excluirComanda(id);
    listarComandas('');
    return res;
  }

  Future<bool> cadastrarComanda(String nome) async {
    final res = await _service.cadastrarComanda(nome);
    listarComandas('');
    return res;
  }

  Future<bool> editarComanda(String id, String nome) async {
    final res = await _service.editarComanda(id, nome);
    listarComandas('');
    return res;
  }
}
