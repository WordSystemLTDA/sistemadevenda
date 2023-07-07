import 'dart:convert';

import 'package:app/src/features/produtos/interactor/models/categoria_model.dart';
import 'package:app/src/features/produtos/interactor/services/categoria_service.dart';
import 'package:http/http.dart' as http;

class CategoriaServiceImpl implements CategoriaService {
  @override
  Future<List<CategoriaModel>> listar() async {
    final response = await http.get(Uri.parse(
      'http://10.1.1.15/api_restaurantes/categorias/listar.php',
    ));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // return Future.delayed(const Duration(seconds: 2), () => List<CategoriaModel>.from(
      //   json.map((elemento) {
      //     return CategoriaModel.fromJson(elemento);
      //   }),
      //));

      return List<CategoriaModel>.from(
        json.map((elemento) {
          return CategoriaModel.fromJson(elemento);
        }),
      );
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
