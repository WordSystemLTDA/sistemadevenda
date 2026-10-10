import 'package:app/src/essencial/api/conexao.dart';
import 'package:dio/dio.dart';
import 'politica_consultas_http.dart';
import 'adaptador_http_prioritario.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';

class DioCliente {
  CacheConsultas? cache;
  String? _servidor;
  DioCliente({String? servidor}) {
    cliente.httpClientAdapter =
        AdaptadorHttpPrioritario(cliente.httpClientAdapter);
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

  Future<String> obterServidor() async =>
      _servidor ?? (await Apis().getConexao()).servidor;

  void configurar({String? servidor}) {
    _servidor = servidor;
    cliente.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          try {
            PoliticaConsultasHttp.preparar(options);
            options.baseUrl = options.extra['servidorFixo'] as String? ??
                await obterServidor();
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
