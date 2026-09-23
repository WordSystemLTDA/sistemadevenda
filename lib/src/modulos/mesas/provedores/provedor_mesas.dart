import 'package:app/src/essencial/api/socket/atualizacao_agrupada.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
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

  /// Reflete imediatamente uma finalização já confirmada pela API. A consulta
  /// seguinte continua sendo a fonte definitiva e corrige qualquer diferença.
  void marcarAtendimentoFinalizado(String idAtendimento) {
    MesaModelo? finalizada;
    for (final grupo in mesas) {
      final itens = grupo.mesas;
      if (itens == null) continue;
      final indice = itens.indexWhere(
          (item) => item.idComandaPedido?.toString() == idAtendimento);
      if (indice >= 0) {
        final item = itens.removeAt(indice);
        final mapa = item.toMap()
          ..addAll({
            'mesaOcupada': false,
            'idCliente': null,
            'nomeCliente': null,
            'obs': null,
            'dataAbertura': null,
            'horaAbertura': null,
            'idComandaPedido': null,
            'valor': null,
            'ultimaVezAbertoDataHora': DateTime.now().toIso8601String(),
            'dataultimopedido': null,
            'fechamento': false,
          });
        finalizada = MesaModelo.fromMap(mapa);
        break;
      }
    }
    if (finalizada == null) return;
    ++_consulta;

    MesasModel? grupoLivres;
    for (final grupo in mesas) {
      if (grupo.titulo.toLowerCase() == 'livres') {
        grupoLivres = grupo;
        break;
      }
    }
    grupoLivres ??= MesasModel(titulo: 'Livres', mesas: []);
    if (!mesas.contains(grupoLivres)) mesas.add(grupoLivres);
    grupoLivres.mesas ??= [];
    grupoLivres.mesas!
      ..removeWhere((item) => item.id == finalizada!.id)
      ..add(finalizada);
    grupoLivres.mesas!.sort((a, b) {
      final primeiro = int.tryParse(a.id);
      final segundo = int.tryParse(b.id);
      return primeiro != null && segundo != null
          ? primeiro.compareTo(segundo)
          : a.nome.compareTo(b.nome);
    });
    notifyListeners();
  }

  final _atualizacao = AtualizacaoAgrupada();

  Future<List<MesasModel>> listarMesas(String pesquisa,
      {bool mostrarCarregamento = true}) async {
    final consulta = ++_consulta;
    await _atualizacao.executar(() async {
      if (mostrarCarregamento && mesas.isEmpty) {
        listando = true;
        notifyListeners();
      }
      erro = null;

      try {
        final res = await _servico.listar(pesquisa);
        if (consulta != _consulta) return;
        mesas = res;
        return;
      } catch (_) {
        if (consulta == _consulta) {
          erro = _mensagemFalha;
        }
        return;
      } finally {
        if (consulta == _consulta) {
          listando = false;
          notifyListeners();
        }
      }
    });
    return mesas;
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
      if (res.sucesso && !AtendimentosLocais.local(res.idcomandapedido)) {
        listarMesas('');
      }
      return res;
    } catch (e) {
      erro = e is StateError ? e.message.toString() : _mensagemFalha;
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

  @override
  void dispose() {
    ++_consulta;
    ++_consultaLista;
    _atualizacao.dispose();
    super.dispose();
  }
}
