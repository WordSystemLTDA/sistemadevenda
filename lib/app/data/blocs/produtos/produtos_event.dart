abstract class ProdutosEvent {}

class GetProdutos extends ProdutosEvent {
  final String category;

  GetProdutos({required this.category});
}
