import 'dart:convert';

import 'package:app/src/features/produtos/interactor/models/produto_model.dart';
import 'package:app/src/features/produtos/interactor/services/produto_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:http/http.dart' as http;

class ProdutoServiceImpl implements ProdutoService {
  @override
  Future<List<ProdutoModel>> listar(String category) async {
    final response = await http.get(
      Uri.parse('${Apis.baseUrl}produtos/listar_por_categoria.php?categoria=$category'),
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
