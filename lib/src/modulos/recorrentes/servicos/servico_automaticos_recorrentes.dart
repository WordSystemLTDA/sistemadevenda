import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:flutter/foundation.dart';

import 'servicos_recorrentes.dart';

/// Mantém o envio automático ativo enquanto o aplicativo estiver aberto,
/// mesmo quando a agenda de recorrentes não estiver na tela.
class ServicoAutomaticosRecorrentes extends ChangeNotifier {
  ServicoAutomaticosRecorrentes(
    this._servico,
    this._usuario,
    this._configuracao, {
    DateTime Function()? agora,
  }) : _agora = agora ?? DateTime.now;

  final ServicosRecorrentes _servico;
  final UsuarioProvedor _usuario;
  final ServicoConfigBigchef _configuracao;
  final DateTime Function() _agora;

  Timer? _temporizador;
  Future<bool>? _execucao;
  String? _sessao;
  String? _ultimoMinutoExecutado;
  bool _habilitado = false;
  bool _iniciado = false;
  int _consultaConfiguracao = 0;

  bool get iniciado => _iniciado;
  bool get executando => _execucao != null;

  void iniciar() {
    if (_iniciado) return;
    _iniciado = true;
    _usuario.addListener(_aoAlterarUsuario);
    _aoAlterarUsuario();
  }

  void encerrar() {
    if (!_iniciado) return;
    _iniciado = false;
    _consultaConfiguracao++;
    _temporizador?.cancel();
    _temporizador = null;
    _usuario.removeListener(_aoAlterarUsuario);
    _sessao = null;
    _ultimoMinutoExecutado = null;
    _habilitado = false;
  }

  void _aoAlterarUsuario() {
    final novaSessao = _sessaoAtual;
    if (novaSessao == _sessao) return;
    _sessao = novaSessao;
    _ultimoMinutoExecutado = null;
    _habilitado = false;
    _temporizador?.cancel();
    _temporizador = null;
    final consulta = ++_consultaConfiguracao;
    if (novaSessao != null) {
      unawaited(_carregarConfiguracao(novaSessao, consulta));
    }
  }

  Future<void> _carregarConfiguracao(String sessao, int consulta) async {
    final config = await _configuracao.listar();
    if (!_iniciado ||
        consulta != _consultaConfiguracao ||
        sessao != _sessaoAtual) {
      return;
    }
    _habilitado = config?.recorrentesHabilitados == true;
    _sincronizarAgendamento();
  }

  String? get _sessaoAtual {
    final usuario = _usuario.usuario;
    final id = usuario?.id?.trim() ?? '';
    final empresa = usuario?.empresa?.trim() ?? '';
    if (id.isEmpty || empresa.isEmpty) return null;
    return '$empresa:$id';
  }

  bool get _podeProcessar =>
      _iniciado && _habilitado && _sessao != null && _sessao == _sessaoAtual;

  void _sincronizarAgendamento() {
    _temporizador?.cancel();
    _temporizador = null;
    if (!_podeProcessar) return;
    unawaited(processarAgora());
    _agendarProximoMinuto();
  }

  void _agendarProximoMinuto() {
    _temporizador?.cancel();
    if (!_podeProcessar) {
      _temporizador = null;
      return;
    }
    _temporizador = Timer(atrasoAteProximoMinuto(_agora()), () {
      _temporizador = null;
      unawaited(_executarCiclo());
    });
  }

  Future<void> _executarCiclo() async {
    await processarAgora();
    if (_podeProcessar) _agendarProximoMinuto();
  }

  /// Faz uma conferência leve na API. Chamadas simultâneas compartilham a
  /// mesma execução e normalmente há, no máximo, uma chamada por minuto.
  Future<bool> processarAgora({bool forcar = false}) {
    final atual = _execucao;
    if (atual != null) return atual;
    if (!_podeProcessar) return Future<bool>.value(false);

    final sessao = _sessao!;
    final chaveMinuto = _chaveMinuto(sessao, _agora());
    if (!forcar && chaveMinuto == _ultimoMinutoExecutado) {
      return Future<bool>.value(false);
    }
    _ultimoMinutoExecutado = chaveMinuto;

    final execucao = _processar(sessao);
    _execucao = execucao;
    return execucao;
  }

  Future<bool> _processar(String sessao) async {
    try {
      await _servico.processarAutomaticos();
      if (_iniciado && sessao == _sessaoAtual && _podeProcessar) {
        notifyListeners();
      }
      return true;
    } catch (_) {
      // A próxima virada de minuto tenta novamente sem bloquear o aplicativo.
      return false;
    } finally {
      _execucao = null;
    }
  }

  static String _chaveMinuto(String sessao, DateTime instante) =>
      '$sessao:${instante.year}-${instante.month}-${instante.day}-${instante.hour}-${instante.minute}';

  @visibleForTesting
  static Duration atrasoAteProximoMinuto(DateTime instante) {
    final proximo = DateTime(
      instante.year,
      instante.month,
      instante.day,
      instante.hour,
      instante.minute + 1,
    );
    return proximo.difference(instante);
  }

  @override
  void dispose() {
    encerrar();
    super.dispose();
  }
}
