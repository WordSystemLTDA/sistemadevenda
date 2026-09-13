class FalhaPedidoVoz implements Exception {
  final String mensagem;
  const FalhaPedidoVoz(this.mensagem);
  @override
  String toString() => mensagem;
}
