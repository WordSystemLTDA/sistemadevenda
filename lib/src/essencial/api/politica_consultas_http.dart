import 'package:dio/dio.dart';

/// Consultas operacionais devem refletir o banco, inclusive em proxies antigos.
abstract final class PoliticaConsultasHttp {
  static int _sequencia = 0;
  static const parametroAtualizacao = '_consulta_atual';

  static void preparar(RequestOptions options) {
    if (options.method.toUpperCase() != 'GET' ||
        !options.uri.path.toLowerCase().endsWith('.php')) {
      return;
    }
    options.headers['Cache-Control'] = 'no-cache, no-store, max-age=0';
    options.headers['Pragma'] = 'no-cache';
    // Ha instalacoes cujo FastCGI ignora os cabecalhos da requisicao.
    // Copiar evita modificar o mapa de parametros mantido pelo chamador.
    options.queryParameters = Map<String, dynamic>.of(options.queryParameters)
      ..[parametroAtualizacao] =
          '${DateTime.now().microsecondsSinceEpoch}-${_sequencia++}';
  }

  static bool permiteRepeticao(RequestOptions options) {
    // Um 502/504 pode ocorrer DEPOIS do commit. POST sem chave de
    // idempotencia nunca pode ser repetido pelo interceptor generico.
    return const {'GET', 'HEAD', 'OPTIONS'}
        .contains(options.method.toUpperCase());
  }
}
