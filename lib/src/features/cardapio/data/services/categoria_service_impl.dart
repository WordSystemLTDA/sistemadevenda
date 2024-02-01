import 'package:app/src/features/cardapio/interactor/models/categoria_model.dart';
import 'package:app/src/features/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class CategoriaServiceImpl implements CategoriaService {
  final Dio dio = Dio();

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
}
