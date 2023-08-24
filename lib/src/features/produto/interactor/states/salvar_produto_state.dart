sealed class SalvarProdutoState {}

class SalvarProdutoInicioState extends SalvarProdutoState {}

class SalvarProdutoCarregandoState extends SalvarProdutoState {}

class SalvarProdutoSucessoState extends SalvarProdutoState {}

class SalvarProdutoErroState extends SalvarProdutoState {
  final Exception exception;
  SalvarProdutoErroState({required this.exception}) : super();
}
