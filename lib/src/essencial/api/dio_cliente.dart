import 'package:app/src/essencial/api/conexao.dart';
import 'package:dio/dio.dart';

class DioCliente {
  // Future<Dio> call() async {
  var cliente = Dio(
    BaseOptions(
      baseUrl: Apis().getConexao(),
      connectTimeout: const Duration(seconds: 30),
    ),
  );
  // }
}
