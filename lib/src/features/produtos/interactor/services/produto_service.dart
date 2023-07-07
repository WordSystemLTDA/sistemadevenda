import 'package:app/src/features/produtos/interactor/models/produto_model.dart';

abstract interface class ProdutoService {
  Future<List<ProdutoModel>> listar(String category);
}
