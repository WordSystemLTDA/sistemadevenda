import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class FeedbackUsuario {
  const FeedbackUsuario._();

  static void produtoAdicionado() {
    _executar(HapticFeedback.heavyImpact);
  }

  static void selecaoAlterada() {
    _executar(HapticFeedback.mediumImpact);
  }

  static void pedidoFinalizado() {
    _executar(HapticFeedback.heavyImpact);
  }

  static void _executar(Future<void> Function() acao) {
    unawaited(() async {
      try {
        await acao();
      } catch (erro, stack) {
        if (kDebugMode) {
          log('Falha ao executar feedback haptico',
              error: erro, stackTrace: stack);
        }
      }
    }());
  }
}
