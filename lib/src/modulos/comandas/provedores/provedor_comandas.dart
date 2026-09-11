import 'package:app/src/modulos/comandas/modelos/modelo_comanda.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:flutter/material.dart';

// final ValueNotifier comandasState = ValueNotifier([]);

class ProvedorComanda extends ChangeNotifier {
  final ServicoComandas _servico;
  ProvedorComanda(this._servico);

  List<ModeloComandas> comandas = [];
  List<ModeloComanda> comandasLista = [];
  bool listando = false;
  String? erro;
  int _consulta = 0;
  int _consultaLista = 0;

  static const _mensagemFalha =
      'Não foi possível conectar ao servidor. Verifique a conexão e tente novamente.';

  Future<List<ModeloComandas>> listarComandas(String pesquisa) async {
    final consulta = ++_consulta;
    listando = true;
    erro = null;
    notifyListeners();

    try {
      final res = await _servico.listar(pesquisa);
      if (consulta != _consulta) return comandas;
      comandas = res;
      return res;
    } catch (_) {
      if (consulta == _consulta) {
        erro = _mensagemFalha;
      }
      return comandas;
    } finally {
      if (consulta == _consulta) {
        listando = false;
        notifyListeners();
      }
    }
  }

  Future<void> listarComandasLista(String pesquisa) async {
    final consulta = ++_consultaLista;
    try {
      final res = await _servico.listarLista(pesquisa);
      if (consulta != _consultaLista) return;
      comandasLista = res;
      erro = null;
    } catch (_) {
      if (consulta == _consultaLista) {
        erro = _mensagemFalha;
      }
    } finally {
      if (consulta == _consultaLista) notifyListeners();
    }
  }

  Future<List<dynamic>> listarMesas(String pesquisa) async {
    try {
      return await _servico.listarMesa(pesquisa);
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return [];
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

  Future<({bool sucesso, String? idcomandapedido})> inserirComandaOcupada(
      String id, String idMesa, String idCliente, String obs) async {
    try {
      final res =
          await _servico.inserirComandaOcupada(id, idMesa, idCliente, obs);

      if (res.sucesso) {
        listarComandas('');
      }

      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return (sucesso: false, idcomandapedido: null);
    }
  }

  Future<dynamic> editarComandaOcupada(
      String id, String idMesa, String idCliente, String obs) async {
    try {
      final res =
          await _servico.editarComandaOcupada(id, idMesa, idCliente, obs);

      if (res) {
        listarComandas('');
      }
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }

  Future<
          ({
            bool sucesso,
            String idcliente,
            String nomecliente,
            String mensagem
          })>
      inserirCliente(
          String nome, String celular, String email, String obs) async {
    try {
      return await _servico.inserirCliente(nome, celular, email, obs);
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return (
        sucesso: false,
        idcliente: '',
        nomecliente: '',
        mensagem: _mensagemFalha,
      );
    }
  }

  Future<bool> editarAtivo(String id, String ativo) async {
    try {
      final res = await _servico.editarAtivo(id, ativo);
      listarComandas('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, dynamic>> excluirComanda(String id) async {
    try {
      final res = await _servico.excluirComanda(id);
      listarComandas('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return {'sucesso': false, 'mensagem': _mensagemFalha};
    }
  }

  Future<bool> cadastrarComanda(String nome) async {
    try {
      final res = await _servico.cadastrarComanda(nome);
      listarComandas('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarComanda(String id, String codigo, String nome) async {
    try {
      final res = await _servico.editarComanda(id, codigo, nome);
      listarComandas('');
      return res;
    } catch (_) {
      erro = _mensagemFalha;
      notifyListeners();
      return false;
    }
  }
}
