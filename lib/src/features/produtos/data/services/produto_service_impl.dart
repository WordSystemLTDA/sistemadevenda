import 'package:app/src/features/produtos/interactor/models/produto_model.dart';
import 'package:app/src/features/produtos/interactor/services/produto_service.dart';
import 'package:app/src/shared/services/api.dart';
import 'package:dio/dio.dart';

class ProdutoServiceImpl implements ProdutoService {
  final Dio dio;

  ProdutoServiceImpl(this.dio);

  @override
  Future<List<ProdutoModel>> listar(String category) async {
    final response = await dio.get('${Apis.baseUrl}produtos/listar_por_categoria.php?categoria=$category');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<ProdutoModel>.from(response.data.map((elemento) {
          return ProdutoModel.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return Future.error("Ops! Um erro ocorreu.");
    }
  }
}
