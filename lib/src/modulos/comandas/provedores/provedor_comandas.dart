import 'package:app/src/essencial/api/socket/atualizacao_agrupada.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
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
    ModeloComanda? atualizada;
    for (final grupo in comandas) {
      for (final item in grupo.comandas ?? const <ModeloComanda>[]) {
        if (item.idComandaPedido?.toString() == idAtendimento ||
            (idRecurso != null &&
                idRecurso.isNotEmpty &&
                item.id == idRecurso &&
                item.comandaOcupada)) {
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
    ModeloComanda? finalizada;
    for (final grupo in comandas) {
      final itens = grupo.comandas;
      if (itens == null) continue;
      final indice = itens.indexWhere((item) =>
          item.idComandaPedido?.toString() == idAtendimento ||
          (idRecurso != null &&
              idRecurso.isNotEmpty &&
              item.id == idRecurso &&
              item.comandaOcupada));
      if (indice >= 0) {
        finalizada = itens.removeAt(indice);
        final idListado = finalizada.idComandaPedido?.toString();
        if (idListado != null && idListado.isNotEmpty) {
          _finalizacoesPendentes.add(idListado);
          _pedidosRecentes.remove(idListado);
        }
        break;
      }
    }
    if (finalizada == null) return;

    _moverParaLivres(finalizada, comandas);
    notifyListeners();
  }

  void _moverParaLivres(ModeloComanda finalizada, List<ModeloComandas> grupos) {
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
    for (final grupo in grupos) {
      if (grupo.titulo.toLowerCase() == 'livres') {
        grupoLivres = grupo;
        break;
      }
    }
    grupoLivres ??= ModeloComandas(titulo: 'Livres', comandas: []);
    if (!grupos.contains(grupoLivres)) grupos.add(grupoLivres);
    grupoLivres.comandas ??= [];
    grupoLivres.comandas!
      ..removeWhere((item) => item.id == finalizada.id)
      ..add(finalizada);
    grupoLivres.comandas!.sort((a, b) {
      final primeiro = int.tryParse(a.id);
      final segundo = int.tryParse(b.id);
      return primeiro != null && segundo != null
          ? primeiro.compareTo(segundo)
          : a.nome.compareTo(b.nome);
    });
  }

  void _preservarFinalizacoesPendentes(List<ModeloComandas> resposta) {
    if (_finalizacoesPendentes.isEmpty) return;
    final aindaPendentes = <String>{};
    final finalizadas = <ModeloComanda>[];
    for (final grupo in resposta) {
      final itens = grupo.comandas;
      if (itens == null) continue;
      for (var indice = itens.length - 1; indice >= 0; indice--) {
        final id = itens[indice].idComandaPedido?.toString();
        if (id == null || !_finalizacoesPendentes.contains(id)) continue;
        aindaPendentes.add(id);
        finalizadas.add(itens.removeAt(indice));
      }
    }
    for (final finalizada in finalizadas) {
      _moverParaLivres(finalizada, resposta);
    }
    _finalizacoesPendentes
      ..clear()
      ..addAll(aindaPendentes);
  }

  void _preservarPedidosRecentes(List<ModeloComandas> resposta) {
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
      for (final item in grupo.comandas ?? const <ModeloComanda>[]) {
        final id = item.idComandaPedido?.toString();
        final entrada = id != null && _pedidosRecentes.containsKey(id)
            ? MapEntry(id, _pedidosRecentes[id]!)
            : recentesPorRecurso[item.id];
        final recente = entrada?.value;
        if (recente == null || !item.comandaOcupada) continue;
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

  Future<List<ModeloComandas>> listarComandas(String pesquisa,
      {bool mostrarCarregamento = true}) async {
    final consulta = ++_consulta;
    await _atualizacao.executar(() async {
      if (mostrarCarregamento && comandas.isEmpty) {
        listando = true;
        notifyListeners();
      }
      erro = null;

      try {
        final res = await _servico.listar(pesquisa);
        if (consulta != _consulta) return;
        _preservarFinalizacoesPendentes(res);
        _preservarPedidosRecentes(res);
        comandas = res;
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
    return comandas;
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

      // A abertura local ja e projetada pela sincronizacao. Evita uma consulta
      // que ainda enxergaria o servidor antes do commit e concorreria com o
      // POST prioritario da abertura.
      if (res.sucesso && !AtendimentosLocais.local(res.idcomandapedido ?? '')) {
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

  @override
  void dispose() {
    ++_consulta;
    ++_consultaLista;
    _atualizacao.dispose();
    super.dispose();
  }
}
