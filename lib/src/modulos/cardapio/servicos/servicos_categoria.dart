import 'dart:convert';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/shared_prefs/shared_prefs_config.dart';
import 'package:app/src/modulos/cardapio/modelos/categoria_model.dart';
import 'package:dio/dio.dart';

class ServicosCategoria {
  final Dio dio = Dio();
  final sharedPrefs = SharedPrefsConfig();

  Future<List<CategoriaModel>> listar() async {
    final conexao = await Apis().getConexao();
    final empresa = jsonDecode(await sharedPrefs.getUsuario())['empresa'];
    if (conexao == null) return [];
    final response = await dio.get('${conexao['servidor']}categorias/listar.php?empresa=$empresa');

    if (response.statusCode == 200) {
      return List<CategoriaModel>.from(
        response.data.map((elemento) {
          return CategoriaModel.fromMap(elemento);
        }),
      );
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
