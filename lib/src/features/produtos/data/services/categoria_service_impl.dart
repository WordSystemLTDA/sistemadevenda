import 'package:app/src/features/produtos/interactor/models/categoria_model.dart';
import 'package:app/src/features/produtos/interactor/services/categoria_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class CategoriaServiceImpl implements CategoriaService {
  final Dio dio;

  CategoriaServiceImpl(this.dio);

  @override
  Future<List<CategoriaModel>> listar() async {
    final response = await dio.get('${Apis.baseUrl}categorias/listar.php');

    if (response.statusCode == 200) {
      // final json = jsonDecode(response.data);

      // return Future.delayed(const Duration(seconds: 2), () => List<CategoriaModel>.from(
      //   json.map((elemento) {
      //     return CategoriaModel.fromJson(elemento);
      //   }),
      //));

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
