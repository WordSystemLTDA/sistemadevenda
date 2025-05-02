import 'dart:developer';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/config/config_modelo.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoConfig {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  final ConfigProvider configProvedor;
  ServicoConfig(this.dio, this.usuarioProvedor, this.configProvedor);

  static const caminhoAPI = 'config';

  Future<ConfigModelo?> listar() async {
    var idEmpresa = usuarioProvedor.usuario!.empresa!;

    try {
      var baseurl = (await Apis().getConexao(tipo: 'online')).servidor;

      var novoDioCliente = Dio(
        BaseOptions(
          baseUrl: baseurl,
          connectTimeout: const Duration(seconds: 10),
        ),
      );

      final List<ConnectivityResult> connectivityResult = await (Connectivity().checkConnectivity());

      Dio novodio;

      if (connectivityResult.contains(ConnectivityResult.none)) {
        novodio = dio.cliente;
      } else {
        novodio = novoDioCliente;
      }

      var response = await novodio.get('$caminhoAPI/listar.php?empresa=$idEmpresa');
      var jsonData = response.data;
      var config = ConfigModelo.fromMap(jsonData['dadosConfig']);
      configProvedor.setConfig(config);

      return config;
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      return null;
    }
  }
}
