import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/features/mesas/interactor/models/mesa_modelo.dart';
import 'package:flutter/material.dart';

final ValueNotifier<Map<String, List<MesaModelo>>> listaMesaState = ValueNotifier({'mesasOcupadas': [], 'mesasLivres': []});

class MesaState {
  final MesaServiceImpl _service = MesaServiceImpl();

  Future<void> listarMesas(String pesquisa) async {
    final res = await _service.listar(pesquisa);
    listaMesaState.value = res;
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _service.listarClientes(pesquisa);
  }

  Future<bool> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
    final res = await _service.inserirMesaOcupada(idMesa, idCliente, obs);
    if (res) {
      listarMesas('');
    }
    return res;
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final res = await _service.editarAtivo(id, ativo);
    listarMesas('');
    return res;
  }

  Future<Map<String, dynamic>> excluirMesa(String id) async {
    final res = await _service.excluirMesa(id);
    listarMesas('');
    return res;
  }

  Future<bool> cadastrarMesa(String nome) async {
    final res = await _service.cadastrarMesa(nome);
    listarMesas('');
    return res;
  }

  Future<bool> editarMesa(String id, String nome) async {
    final res = await _service.editarMesa(id, nome);
    listarMesas('');
    return res;
  }
}
