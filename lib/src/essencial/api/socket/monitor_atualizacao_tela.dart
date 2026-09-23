import 'dart:async';

import 'package:flutter/widgets.dart';

import 'atualizacao_agrupada.dart';

/// Reconcilia a tela visivel mesmo quando um evento de socket foi perdido.
/// O intervalo comeca depois da ultima consulta, inclusive a recebida por evento.
/// Nao acumula polling nem inicia uma leitura com o app suspenso.
class MonitorAtualizacaoTela with WidgetsBindingObserver {
  MonitorAtualizacaoTela({
    required this.atualizar,
    required this.estaAtiva,
    Duration intervalo = const Duration(seconds: 5),
  }) : _intervalo = intervalo {
    if (intervalo <= Duration.zero) {
      throw ArgumentError.value(intervalo, 'intervalo', 'Deve ser positivo');
    }
    WidgetsBinding.instance.addObserver(this);
    _agendarProxima();
  }

  final Future<void> Function() atualizar;
  final bool Function() estaAtiva;
  final Duration _intervalo;
  final _fila = AtualizacaoAgrupada();
  Timer? _timer;
  bool _descartado = false;

  bool get _appAtivo =>
      WidgetsBinding.instance.lifecycleState == null ||
      WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;

  bool get _podeAtualizar => !_descartado && _appAtivo && estaAtiva();

  void _agendarProxima() {
    _timer?.cancel();
    _timer = null;
    if (!_descartado && _appAtivo && !_fila.emAndamento) {
      _timer = Timer(_intervalo, () => unawaited(solicitar()));
    }
  }

  Future<void> solicitar() async {
    if (!_podeAtualizar) {
      _agendarProxima();
      return;
    }
    _timer?.cancel();
    try {
      await _fila.executar(() async {
        // Um evento pode ter aguardado uma consulta enquanto a tela foi fechada
        // ou o app suspenso. Revalida antes de iniciar a leitura pendente.
        if (_podeAtualizar) await atualizar();
      });
    } catch (erro) {
      // A tela conserva os dados anteriores; o proximo ciclo tenta novamente.
      debugPrint('[AtualizacaoTela] Falha ao reconciliar: $erro');
    } finally {
      _agendarProxima();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(solicitar());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void dispose() {
    _descartado = true;
    _timer?.cancel();
    _fila.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }
}
