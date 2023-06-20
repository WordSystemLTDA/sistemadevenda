import 'dart:convert';

import 'package:app/app/data/models/produto_model.dart';
import 'package:http/http.dart' as http;

class ProdutoRepository {
  Future<List<ProdutoModel>> listar(String category) async {
    final response = await http.get(
      Uri.parse('http://10.1.1.15/api_restaurantes/produtos/listar_por_categoria.php?categoria=$category'),
    );

    if (response.statusCode == 200) {
      if (response.body.isNotEmpty) {
        final json = jsonDecode(response.body);

        return List<ProdutoModel>.from(json.map((elemento) {
          return ProdutoModel.fromJson(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
