import 'package:app/src/essencial/api/conexao.dart';
import 'package:dio/dio.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';

class DioCliente {
  CacheConsultas? cache;
  DioCliente({String? servidor}) {
    configurar(servidor: servidor);
  }

  static const tempoConexao = Duration(seconds: 10);
  static const tempoEnvio = Duration(seconds: 30);
  static const tempoResposta = Duration(seconds: 30);

  var cliente = Dio(BaseOptions(
    connectTimeout: tempoConexao,
    sendTimeout: tempoEnvio,
    receiveTimeout: tempoResposta,
  ));

  void configurar({String? servidor}) {
    // cliente.options.baseUrl = servidor ?? (await Apis().getConexao()).servidor;
    // cliente = Dio(
    //   BaseOptions(
    //     baseUrl: servidor ?? (await Apis().getConexao()).servidor,
    //     connectTimeout: const Duration(seconds: 10),
    //   ),
    // ); 

    cliente.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            options.baseUrl = options.extra['servidorFixo'] as String? ??
                servidor ??
                (await Apis().getConexao()).servidor;
            handler.next(options);
          } catch (erro, stack) {
            handler.reject(DioException(
                requestOptions: options, error: erro, stackTrace: stack));
          }
        },
      ),
    );
    final banco = BancoLocal.instancia;
    if (banco != null && cache == null) {
      cache = CacheConsultas(cliente, banco);
      cliente.interceptors.add(cache!);
    }
  }
}
