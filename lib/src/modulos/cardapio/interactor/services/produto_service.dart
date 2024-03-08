import 'package:app/src/modulos/cardapio/interactor/models/produto_model.dart';

abstract interface class ProdutoService {
  Future<List<ProdutoModel>> listar(String category);
}
