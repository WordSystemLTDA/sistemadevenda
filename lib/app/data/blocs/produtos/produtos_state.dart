import 'package:app/app/data/models/produto_model.dart';

abstract class ProdutosState {
  final List<ProdutoModel> produtos;

  ProdutosState({required this.produtos});
}

class ProdutoInitialState extends ProdutosState {
  ProdutoInitialState() : super(produtos: []);
}

class ProdutoLoadingState extends ProdutosState {
  ProdutoLoadingState() : super(produtos: []);
}

class ProdutoLoadedState extends ProdutosState {
  ProdutoLoadedState({required List<ProdutoModel> produtos}) : super(produtos: produtos);
}

class ProdutoErrorState extends ProdutosState {
  final Exception exception;

  ProdutoErrorState({required this.exception}) : super(produtos: []);
}
