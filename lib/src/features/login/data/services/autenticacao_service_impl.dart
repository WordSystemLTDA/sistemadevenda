import 'dart:convert';
import 'dart:io';

import 'package:app/src/features/login/interactor/services/autenticacao_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class AutenticacaoServiceImpl implements AutenticacaoService {
  final Dio dio;

  AutenticacaoServiceImpl(this.dio);

  @override
  Future<bool> entrar(usuario, senha) async {
    var campos = {
      "usuario": usuario,
      "senha": senha,
    };

    final response = await dio.post(
      '${Apis.baseUrl}autenticacao/entrar.php',
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      }),
      data: jsonEncode(campos),
    );

    Map result = response.data;
    bool sucesso = result['sucesso'];

    if (response.statusCode == 200) {
      return sucesso;
    } else {
      return false;
    }
  }
}
