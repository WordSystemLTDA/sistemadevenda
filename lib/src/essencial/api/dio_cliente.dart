import 'package:app/src/essencial/api/conexao.dart';
import 'package:dio/dio.dart';

class DioCliente {
  DioCliente() {
    configurar();
  }

  var cliente = Dio(BaseOptions(connectTimeout: const Duration(seconds: 30)));

  void configurar() async {
    cliente.options.baseUrl = (await Apis().getConexao()).servidor;
  }
}
