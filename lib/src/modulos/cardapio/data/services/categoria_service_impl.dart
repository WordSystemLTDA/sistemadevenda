import 'package:app/src/essencial/services/api.dart';
import 'package:app/src/modulos/cardapio/interactor/models/categoria_model.dart';
import 'package:app/src/modulos/cardapio/interactor/services/categoria_service.dart';
import 'package:dio/dio.dart';

class CategoriaServiceImpl implements CategoriaService {
  final Dio dio = Dio();

  @override
  Future<List<CategoriaModel>> listar() async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final response = await dio.get('${conexao['servidor']}categorias/listar.php');

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
