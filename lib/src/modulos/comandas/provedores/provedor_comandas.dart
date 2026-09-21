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

  /// Reflete imediatamente uma finalização já confirmada pela API. A consulta
  /// seguinte continua sendo a fonte definitiva e corrige qualquer diferença.
  void marcarAtendimentoFinalizado(String idAtendimento) {
    ModeloComanda? finalizada;
    for (final grupo in comandas) {
      final itens = grupo.comandas;
      if (itens == null) continue;
      final indice = itens.indexWhere(
          (item) => item.idComandaPedido?.toString() == idAtendimento);
      if (indice >= 0) {
        finalizada = itens.removeAt(indice);
        break;
      }
    }
    if (finalizada == null) return;

    final agora = DateTime.now().toIso8601String();
    finalizada
      ..comandaOcupada = false
      ..fechamento = false
      ..idCliente = null
      ..nomeCliente = null
      ..obs = null
      ..nomeMesa = null
      ..idmesa = null
      ..dataAbertura = null
      ..horaAbertura = null
      ..dataultimopedido = null
      ..idComandaPedido = null
      ..valor = null
      ..ultimaVezAbertoDataHora = agora;

    ModeloComandas? grupoLivres;
    for (final grupo in comandas) {
      if (grupo.titulo.toLowerCase() == 'livres') {
        grupoLivres = grupo;
        break;
      }
    }
    grupoLivres ??= ModeloComandas(titulo: 'Livres', comandas: []);
    if (!comandas.contains(grupoLivres)) comandas.add(grupoLivres);
    grupoLivres.comandas ??= [];
    grupoLivres.comandas!
      ..removeWhere((item) => item.id == finalizada!.id)
      ..add(finalizada);
    grupoLivres.comandas!.sort((a, b) {
      final primeiro = int.tryParse(a.id);
      final segundo = int.tryParse(b.id);
      return primeiro != null && segundo != null
          ? primeiro.compareTo(segundo)
          : a.nome.compareTo(b.nome);
    });
    notifyListeners();
  }

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
    } catch (e) {
      erro = e is StateError ? e.message.toString() : _mensagemFalha;
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
