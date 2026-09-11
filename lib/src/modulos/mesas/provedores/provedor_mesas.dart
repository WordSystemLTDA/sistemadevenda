import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:app/src/modulos/mesas/modelos/mesas_model.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:flutter/material.dart';

class ProvedorMesas extends ChangeNotifier {
  final ServicoMesas _servico;
  ProvedorMesas(this._servico);

  List<MesasModel> mesas = [];
  List<MesaModelo> mesasLista = [];
  bool listando = false;
  String? erro;
  int _consulta = 0;
  int _consultaLista = 0;

  static const _mensagemFalha =
      'Não foi possível conectar ao servidor. Verifique a conexão e tente novamente.';

  Future<List<MesasModel>> listarMesas(String pesquisa) async {
    final consulta = ++_consulta;
    listando = true;
    erro = null;
    notifyListeners();

    try {
      final res = await _servico.listar(pesquisa);
      if (consulta != _consulta) return mesas;
      mesas = res;
      return res;
    } catch (_) {
      if (consulta == _consulta) {
        erro = _mensagemFalha;
      }
      return mesas;
    } finally {
      if (consulta == _consulta) {
        listando = false;
        notifyListeners();
      }
    }
  }

  Future<void> listarMesasLista(String pesquisa) async {
    final consulta = ++_consultaLista;
    try {
      final res = await _servico.listarLista(pesquisa);
      if (consulta != _consultaLista) return;
      mesasLista = res;
      erro = null;
    } catch (_) {
      if (consulta == _consultaLista) {
        erro = _mensagemFalha;
      }
    } finally {
      if (consulta == _consultaLista) notifyListeners();
    }
  }

  Future<List<dynamic>> listarClientes(String pesquisa) async {
    try {
      return await _servico.listarClientes(pesquisa);
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return [];
    }
  }

  Future<({bool sucesso, String idcomandapedido})> inserirMesaOcupada(
      String idMesa, String idCliente, String obs) async {
    try {
      final res = await _servico.inserirMesaOcupada(idMesa, idCliente, obs);
      if (res.sucesso) {
        listarMesas('');
      }
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return (sucesso: false, idcomandapedido: '');
    }
  }

  Future<bool> editarMesaOcupada(
      String id, String idMesa, String idCliente, String obs) async {
    try {
      final res = await _servico.editarMesaOcupada(id, idMesa, idCliente, obs);

      if (res) {
        listarMesas('');
      }
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    try {
      final res = await _servico.editarAtivo(id, ativo);
      listarMesasLista('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> excluirMesa(String id) async {
    try {
      final res = await _servico.excluirMesa(id);
      listarMesasLista('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return {'sucesso': false, 'mensagem': _mensagemFalha};
    }
  }

  Future<bool> cadastrarMesa(String nome, String codigo) async {
    try {
      final res = await _servico.cadastrarMesa(nome, codigo);
      listarMesasLista('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarMesa(String id, String nome, String codigo) async {
    try {
      final res = await _servico.editarMesa(id, nome, codigo);
      listarMesasLista('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }
}
