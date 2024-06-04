import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/modulos/cardapio/modelos/produto_model.dart';
import 'package:dio/dio.dart';

class ServicosProduto {
  final Dio dio = Dio();

  Future<List<ProdutoModel>> listarPorCategoria(String category) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final response = await dio.get('${conexao['servidor']}produtos/listar_por_categoria.php?categoria=$category');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<ProdutoModel>.from(response.data.map((elemento) {
          return ProdutoModel.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }

  Future<List<ProdutoModel>> listarPorNome(String pesquisa) async {
    final conexao = await Apis().getConexao();
    if (conexao == null) return [];
    final response = await dio.get('${conexao['servidor']}produtos/listar.php?pesquisa=$pesquisa');

    if (response.statusCode == 200) {
      if (response.data.isNotEmpty) {
        return List<ProdutoModel>.from(response.data.map((elemento) {
          return ProdutoModel.fromMap(elemento);
        }));
      } else {
        return [];
      }
    } else {
      return [];
    }
  }
}
