import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:flutter/material.dart';

class ProvedorMesas extends ChangeNotifier {
  final ServicoMesas _servico;
  ProvedorMesas(this._servico);

  Map<String, List<MesaModelo>> listaMesaState = {'mesasOcupadas': [], 'mesasLivres': []};

  Future<void> listarMesas(String pesquisa) async {
    final res = await _servico.listar(pesquisa);
    listaMesaState = res;
    notifyListeners();
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _servico.listarClientes(pesquisa);
  }

  Future<bool> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
    final res = await _servico.inserirMesaOcupada(idMesa, idCliente, obs);
    if (res) {
      listarMesas('');
    }
    return res;
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final res = await _servico.editarAtivo(id, ativo);
    listarMesas('');
    return res;
  }

  Future<Map<String, dynamic>> excluirMesa(String id) async {
    final res = await _servico.excluirMesa(id);
    listarMesas('');
    return res;
  }

  Future<bool> cadastrarMesa(String nome) async {
    final res = await _servico.cadastrarMesa(nome);
    listarMesas('');
    return res;
  }

  Future<bool> editarMesa(String id, String nome) async {
    final res = await _servico.editarMesa(id, nome);
    listarMesas('');
    return res;
  }
}
