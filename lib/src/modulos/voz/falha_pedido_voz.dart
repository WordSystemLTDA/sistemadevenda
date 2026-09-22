class FalhaPedidoVoz implements Exception {
  final String mensagem;
  const FalhaPedidoVoz(this.mensagem);
  @override
  String toString() => mensagem;
}

class EsclarecimentoPedidoVoz extends FalhaPedidoVoz {
  final String texto;
  const EsclarecimentoPedidoVoz(super.mensagem, this.texto);
}
