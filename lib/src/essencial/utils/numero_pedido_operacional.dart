String? numeroPedidoOperacionalConfirmado(Object? valor) {
  final numero = valor?.toString().trim() ?? '';
  if ((int.tryParse(numero) ?? 0) <= 0) return null;
  return numero;
}

String exigirNumeroPedidoOperacional(Object? valor) {
  final numero = numeroPedidoOperacionalConfirmado(valor);
  if (numero == null) {
    throw StateError(
      'Aguarde o servidor confirmar o número do pedido antes de imprimir.',
    );
  }
  return numero;
}
