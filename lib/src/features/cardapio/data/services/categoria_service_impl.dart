import 'package:app/src/features/cardapio/interactor/models/categoria_model.dart';
import 'package:app/src/features/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class CategoriaServiceImpl implements CategoriaService {
  final Dio dio;

  CategoriaServiceImpl(this.dio);

  @override
  Future<List<CategoriaModel>> listar() async {
    final response = await dio.get('${Apis.baseUrl}categorias/listar.php');

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

  @override
  Future<List<dynamic>> listarComandasPedidos(String idComanda) async {
    final url = '${Apis.baseUrl}/pedidos/listar.php?id_comanda=$idComanda';

    final response = await dio.get(url);

    if (response.statusCode == 200) return response.data;

    return [];

    //     if (response.statusCode == 200) {
    //   return List<CategoriaModel>.from(
    //     response.data.map((elemento) {
    //       return CategoriaModel.fromMap(elemento);
    //     }),
    //   );
    // } else {
    //   return Future.error("Ops! Um erro ocorreu.");
    // }
  }

  @override
  Future<bool> removerComandasPedidos(String idItemComanda) async {
    const url = '${Apis.baseUrl}/pedidos/remover.php';

    final response = await dio.post(
      url,
      data: {'idItemComanda': idItemComanda},
    );

    if (response.statusCode == 200) {
      if (response.data['sucesso']) return true;
      return false;
    }
    return false;
  }
}
