import 'dart:developer';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoConfigBigchef {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoConfigBigchef(this.dio, this.usuarioProvedor);

  static const caminhoAPI = 'config_bigchef';

  Future<ModeloConfigBigchef?> listar() async {
    var idEmpresa = usuarioProvedor.usuario!.empresa!;

    try {
      var response = await dio.cliente.get('$caminhoAPI/listar.php?empresa=$idEmpresa');
      var jsonData = response.data;

      // bool sucesso = jsonData['sucesso'];
      return ModeloConfigBigchef.fromMap(jsonData);
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
