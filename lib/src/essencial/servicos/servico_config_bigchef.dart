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
  static final Map<String, ModeloConfigBigchef> _cachePorEmpresa = {};

  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async {
    final idEmpresa = usuarioProvedor.usuario?.empresa;
    if (idEmpresa == null || idEmpresa.isEmpty) return null;
    if (!forcarAtualizacao && _cachePorEmpresa[idEmpresa] != null) {
      return _cachePorEmpresa[idEmpresa];
    }

    try {
      final response = await dio.cliente.get('$caminhoAPI/listar.php',
          queryParameters: {
            'empresa': idEmpresa,
            if (forcarAtualizacao)
              '_atualizacao': DateTime.now().microsecondsSinceEpoch,
          },
          options: Options(extra: {'semCache': forcarAtualizacao}));
      final jsonData = response.data;
      if (jsonData is! Map) return _cachePorEmpresa[idEmpresa];
      final config =
          ModeloConfigBigchef.fromMap(Map<String, dynamic>.from(jsonData));
      _cachePorEmpresa[idEmpresa] = config;
      return config;
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      return _cachePorEmpresa[idEmpresa];
    }
  }
}
