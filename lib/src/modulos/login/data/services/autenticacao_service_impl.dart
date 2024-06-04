import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/modulos/login/interactor/services/autenticacao_service.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutenticacaoServiceImpl implements AutenticacaoService {
  final Dio dio = Dio();

  @override
  Future<bool> entrar(usuario, senha) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    var campos = {
      "usuario": usuario,
      "senha": senha,
    };

    final conexao = await Apis().getConexao();
    if (conexao == null) return false;
    final response = await dio.post(
      '${conexao['servidor']}autenticacao/entrar.php',
      options: Options(headers: {
        HttpHeaders.contentTypeHeader: "application/json",
      }),
      data: jsonEncode(campos),
    );

    Map result = response.data;
    bool sucesso = result['sucesso'];
    dynamic dados = result['resultado'];

    if (response.statusCode == 200 && sucesso == true) {
      await prefs.setString('usuario', jsonEncode(dados));
      return sucesso;
    } else {
      return false;
    }
  }
}
