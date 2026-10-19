import 'dart:async';
import 'dart:io';

import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:dio/dio.dart';

/// Centraliza a decisão de quando uma falha representa apenas indisponibilidade
/// temporária do servidor. Nessas situações, a interface conserva os dados
/// locais e a sincronização continua tentando em segundo plano.
abstract final class EstadoServidor {
  static bool indisponivel([Object? erro]) {
    if (_falhaDeRede(erro)) return true;

    // Alguns serviços convertem a DioException em StateError antes de chegar à
    // tela. O interceptor já registrou a queda, então consultamos esse estado.
    try {
      final cache = Sincronizador.instancia?.api.cache;
      return cache != null && !cache.servidorDisponivel;
    } catch (_) {
      // Fakes usados por telas/testes podem não implementar a API completa.
      return false;
    }
  }

  static bool _falhaDeRede(Object? erro) {
    if (erro is DioException) return CacheConsultas.falhaDeConexao(erro);
    if (erro is SocketException || erro is TimeoutException) return true;
    return false;
  }
}
