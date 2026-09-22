import 'dart:async';

import 'package:flutter/widgets.dart';

import 'atualizacao_agrupada.dart';

/// Reconcilia a tela visivel mesmo quando um evento de socket foi perdido.
/// A consulta periodica nao acumula requisicoes nem roda com o app suspenso.
class MonitorAtualizacaoTela with WidgetsBindingObserver {
  MonitorAtualizacaoTela({
    required this.atualizar,
    required this.estaAtiva,
    Duration intervalo = const Duration(seconds: 5),
  }) {
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(intervalo, (_) {
      if (!_fila.emAndamento) unawaited(solicitar());
    });
  }

  final Future<void> Function() atualizar;
  final bool Function() estaAtiva;
  final _fila = AtualizacaoAgrupada();
  Timer? _timer;
  bool _descartado = false;

  Future<void> solicitar() async {
    if (_descartado ||
        (WidgetsBinding.instance.lifecycleState != null &&
            WidgetsBinding.instance.lifecycleState !=
                AppLifecycleState.resumed) ||
        !estaAtiva()) {
      return;
    }
    try {
      await _fila.executar(() async {
        if (!_descartado && estaAtiva()) await atualizar();
      });
    } catch (erro) {
      // A tela conserva os dados anteriores; o proximo ciclo tenta novamente.
      debugPrint('[AtualizacaoTela] Falha ao reconciliar: $erro');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(solicitar());
  }

  void dispose() {
    _descartado = true;
    _timer?.cancel();
    _fila.dispose();
    WidgetsBinding.instance.removeObserver(this);
  }
}
