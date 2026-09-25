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
  final Set<String> _finalizacoesPendentes = {};
  final Map<
      String,
      ({
        String? idRecurso,
        double totalMinimo,
        DateTime lancadoEm,
        DateTime ate,
      })> _pedidosRecentes = {};

  static const _mensagemFalha =
      'Não foi possível conectar ao servidor. Verifique a conexão e tente novamente.';

  double _valor(String? valor) =>
      double.tryParse((valor ?? '0').replaceAll(',', '.')) ?? 0;

  /// Atualiza o card assim que a API confirma o lançamento dos produtos. A
  /// listagem pode levar alguns segundos para refletir o novo total; durante
  /// esse intervalo, respostas antigas não substituem o valor já confirmado.
  void registrarPedidoLancado(
    String idAtendimento, {
    String? idRecurso,
    required double valorAdicionado,
  }) {
    if (!valorAdicionado.isFinite || valorAdicionado <= 0) return;
    MesaModelo? atualizada;
    for (final grupo in mesas) {
      for (final item in grupo.mesas ?? const <MesaModelo>[]) {
        if (item.idComandaPedido?.toString() == idAtendimento ||
            (idRecurso != null &&
                idRecurso.isNotEmpty &&
                item.id == idRecurso &&
                item.mesaOcupada)) {
          atualizada = item;
          break;
        }
      }
      if (atualizada != null) break;
    }
    if (atualizada == null) return;

    final agora = DateTime.now();
    final totalMinimo = _valor(atualizada.valor) + valorAdicionado;
    atualizada
      ..valor = totalMinimo.toStringAsFixed(2)
      ..dataultimopedido = agora.toIso8601String();
    final idListado = atualizada.idComandaPedido?.toString();
    final chave = idListado?.isNotEmpty == true ? idListado! : idAtendimento;
    _pedidosRecentes[chave] = (
      idRecurso: idRecurso,
      totalMinimo: totalMinimo,
      lancadoEm: agora,
      ate: agora.add(const Duration(seconds: 45)),
    );
    notifyListeners();
  }

  /// Reflete imediatamente uma finalização já confirmada pela API. Enquanto a
  /// listagem remota ainda devolver o atendimento antigo, ele continua livre
  /// localmente para não reaparecer como ocupado por alguns segundos.
  void marcarAtendimentoFinalizado(String idAtendimento, {String? idRecurso}) {
    ++_consulta;
    _finalizacoesPendentes.add(idAtendimento);
    MesaModelo? finalizada;
    for (final grupo in mesas) {
      final itens = grupo.mesas;
      if (itens == null) continue;
      final indice = itens.indexWhere((item) =>
          item.idComandaPedido?.toString() == idAtendimento ||
          (idRecurso != null &&
              idRecurso.isNotEmpty &&
              item.id == idRecurso &&
              item.mesaOcupada));
      if (indice >= 0) {
        final item = itens.removeAt(indice);
        final idListado = item.idComandaPedido?.toString();
        if (idListado != null && idListado.isNotEmpty) {
          _finalizacoesPendentes.add(idListado);
          _pedidosRecentes.remove(idListado);
        }
        finalizada = _comoLivre(item);
        break;
      }
    }
    if (finalizada == null) return;

    _moverParaLivres(finalizada, mesas);
    notifyListeners();
  }

  MesaModelo _comoLivre(MesaModelo item) {
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
    return MesaModelo.fromMap(mapa);
  }

  void _moverParaLivres(MesaModelo finalizada, List<MesasModel> grupos) {
    MesasModel? grupoLivres;
    for (final grupo in grupos) {
      if (grupo.titulo.toLowerCase() == 'livres') {
        grupoLivres = grupo;
        break;
      }
    }
    grupoLivres ??= MesasModel(titulo: 'Livres', mesas: []);
    if (!grupos.contains(grupoLivres)) grupos.add(grupoLivres);
    grupoLivres.mesas ??= [];
    grupoLivres.mesas!
      ..removeWhere((item) => item.id == finalizada.id)
      ..add(finalizada);
    grupoLivres.mesas!.sort((a, b) {
      final primeiro = int.tryParse(a.id);
      final segundo = int.tryParse(b.id);
      return primeiro != null && segundo != null
          ? primeiro.compareTo(segundo)
          : a.nome.compareTo(b.nome);
    });
  }

  void _preservarFinalizacoesPendentes(List<MesasModel> resposta) {
    if (_finalizacoesPendentes.isEmpty) return;
    final aindaPendentes = <String>{};
    final finalizadas = <MesaModelo>[];
    for (final grupo in resposta) {
      final itens = grupo.mesas;
      if (itens == null) continue;
      for (var indice = itens.length - 1; indice >= 0; indice--) {
        final id = itens[indice].idComandaPedido?.toString();
        if (id == null || !_finalizacoesPendentes.contains(id)) continue;
        aindaPendentes.add(id);
        finalizadas.add(_comoLivre(itens.removeAt(indice)));
      }
    }
    for (final finalizada in finalizadas) {
      _moverParaLivres(finalizada, resposta);
    }
    _finalizacoesPendentes
      ..clear()
      ..addAll(aindaPendentes);
  }

  void _preservarPedidosRecentes(List<MesasModel> resposta) {
    if (_pedidosRecentes.isEmpty) return;
    final agora = DateTime.now();
    final confirmados = <String>{};
    _pedidosRecentes.removeWhere((_, item) => item.ate.isBefore(agora));
    if (_pedidosRecentes.isEmpty) return;
    final recentesPorRecurso = {
      for (final entrada in _pedidosRecentes.entries)
        if (entrada.value.idRecurso?.isNotEmpty == true)
          entrada.value.idRecurso!: entrada,
    };

    for (final grupo in resposta) {
      for (final item in grupo.mesas ?? const <MesaModelo>[]) {
        final id = item.idComandaPedido?.toString();
        final entrada = id != null && _pedidosRecentes.containsKey(id)
            ? MapEntry(id, _pedidosRecentes[id]!)
            : recentesPorRecurso[item.id];
        final recente = entrada?.value;
        if (recente == null || !item.mesaOcupada) continue;
        if (_valor(item.valor) + 0.009 >= recente.totalMinimo) {
          confirmados.add(entrada!.key);
          continue;
        }
        item
          ..valor = recente.totalMinimo.toStringAsFixed(2)
          ..dataultimopedido = recente.lancadoEm.toIso8601String();
      }
    }
    for (final id in confirmados) {
      _pedidosRecentes.remove(id);
    }
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
        _preservarFinalizacoesPendentes(res);
        _preservarPedidosRecentes(res);
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
