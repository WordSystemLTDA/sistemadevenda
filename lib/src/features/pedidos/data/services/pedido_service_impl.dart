import 'dart:convert';

import 'package:app/src/features/pedidos/interactor/models/pedido_model.dart';
import 'package:app/src/features/pedidos/interactor/services/pedidos_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class PedidoServiceImpl implements PedidoService {
  final Dio dio;

  PedidoServiceImpl(this.dio);

  @override
  Future<List<PedidoModel>> listar(String idMesa) async {
    final response = await dio.get('${Apis.baseUrl}pedidos/listar.php?idMesa=$idMesa');

    if (response.statusCode == 200) {
      final json = jsonDecode(response.data);

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
