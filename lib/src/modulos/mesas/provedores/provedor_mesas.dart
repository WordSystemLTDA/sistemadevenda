import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:flutter/material.dart';

class ProvedorMesas extends ChangeNotifier {
  final ServicoMesas _servico;
  ProvedorMesas(this._servico);

  List<MesasModel> mesas = [];
  List<MesaModelo> mesasLista = [];

  Future<List<MesasModel>> listarMesas(String pesquisa) async {
    final res = await _servico.listar(pesquisa);
    mesas = res;
    notifyListeners();
    return res;
  }

  Future<void> listarMesasLista(String pesquisa) async {
    final res = await _servico.listarLista(pesquisa);
    mesasLista = res;
    notifyListeners();
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _servico.listarClientes(pesquisa);
  }

  Future<({bool sucesso, String idcomandapedido})> inserirMesaOcupada(String idMesa, String idCliente, String obs) async {
    final res = await _servico.inserirMesaOcupada(idMesa, idCliente, obs);
    if (res.sucesso) {
      listarMesas('');
    }
    return res;
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final res = await _servico.editarAtivo(id, ativo);
    listarMesasLista('');
    return res;
  }

  Future<Map<String, dynamic>> excluirMesa(String id) async {
    final res = await _servico.excluirMesa(id);
    listarMesasLista('');
    return res;
  }

  Future<bool> cadastrarMesa(String nome, String codigo) async {
    final res = await _servico.cadastrarMesa(nome, codigo);
    listarMesasLista('');
    return res;
  }

  Future<bool> editarMesa(String id, String nome, String codigo) async {
    final res = await _servico.editarMesa(id, nome, codigo);
    listarMesasLista('');
    return res;
  }
}
