import 'dart:convert';

import 'package:app/app/data/models/pedido_model.dart';
import 'package:http/http.dart' as http;

class PedidoRepository {
  Future<List<PedidoModel>> listar(String idMesa) async {
    final response = await http.get(Uri.parse(
      'http://10.1.1.15/api_restaurantes/pedidos/listar.php?idMesa=$idMesa',
    ));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);

      // return Future.delayed(const Duration(seconds: 2), () => List<CategoriaModel>.from(
      //   json.map((elemento) {
      //     return CategoriaModel.fromJson(elemento);
      //   }),
      // ));

      return List<PedidoModel>.from(
        json.map((elemento) {
          return PedidoModel.fromJson(elemento);
        }),
      );
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
