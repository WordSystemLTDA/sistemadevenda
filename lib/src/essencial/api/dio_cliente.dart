import 'package:app/src/essencial/api/conexao.dart';
import 'package:dio/dio.dart';

class DioCliente {
  DioCliente() {
    configurar();
  }

  var cliente = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));

  void configurar({String? servidor}) async {
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
          // Add the access token to the request header
          options.baseUrl = servidor ?? (await Apis().getConexao()).servidor;

          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401) {
            // If a 401 response is received, refresh the access token

            // Update the request header with the new access token
            e.requestOptions.baseUrl = servidor ?? (await Apis().getConexao()).servidor;

            // Repeat the request with the updated header
            return handler.resolve(await cliente.fetch(e.requestOptions));
          }
          return handler.next(e);
        },
      ),
    );
  }
}
