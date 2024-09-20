import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:flutter/material.dart';

final ValueNotifier comandasState = ValueNotifier([]);

class ComandasState {
  final ServicoComandas _servico;
  ComandasState(this._servico);

  Future<void> listarComandas(String pesquisa) async {
    final res = await _servico.listar(pesquisa);
    comandasState.value = res;
  }

  Future<List<dynamic>> listarMesas(String pesquisa) async {
    return await _servico.listarMesa(pesquisa);
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    return await _servico.listarClientes(pesquisa);
  }

  Future<dynamic> inserirComandaOcupada(String id, String idMesa, String idCliente, String obs) async {
    final res = await _servico.inserirComandaOcupada(id, idMesa, idCliente, obs);
    if (res) {
      listarComandas('');
    }
    return res;
  }

  Future<bool> inserirCliente(String nome, String celular, String email, String obs) async {
    return await _servico.inserirCliente(nome, celular, email, obs);
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    final res = await _servico.editarAtivo(id, ativo);
    listarComandas('');
    return res;
  }

  Future<Map<String, dynamic>> excluirComanda(String id) async {
    final res = await _servico.excluirComanda(id);
    listarComandas('');
    return res;
  }

  Future<bool> cadastrarComanda(String nome) async {
    final res = await _servico.cadastrarComanda(nome);
    listarComandas('');
    return res;
  }

  Future<bool> editarComanda(String id, String nome) async {
    final res = await _servico.editarComanda(id, nome);
    listarComandas('');
    return res;
  }
}
