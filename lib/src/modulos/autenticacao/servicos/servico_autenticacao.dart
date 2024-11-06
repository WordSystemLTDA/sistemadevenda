import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServicoAutenticacao {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoAutenticacao(this.dio, this.usuarioProvedor);

  Future<bool> entrar(usuario, senha) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    var campos = {
      "usuario": usuario,
      "senha": senha,
    };

    try {
      final response = await dio.cliente.post(
        'autenticacao/entrar.php',
        options: Options(headers: {
          HttpHeaders.contentTypeHeader: "application/json",
        }),
        data: jsonEncode(campos),
      );

      Map result = response.data;
      bool sucesso = result['sucesso'];
      dynamic dados = result['resultado'];

      if (response.statusCode == 200 && sucesso == true) {
        await prefs.setString(ConfigSharedPreferences.usuario, jsonEncode(dados));
        usuarioProvedor.setUsuario(UsuarioModelo.fromMap(dados));
        return sucesso;
      } else {
        return false;
      }
    } on DioException catch (_) {
      return false;
    }
  }
}
