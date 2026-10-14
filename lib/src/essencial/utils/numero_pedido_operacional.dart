String? numeroPedidoOperacionalConfirmado(Object? valor) {
  final numero = valor?.toString().trim() ?? '';
  if ((int.tryParse(numero) ?? 0) <= 0) return null;
  return numero;
}

/// A sequência do pedido é opcional no comprovante. A identificação do
/// atendimento continua nos campos de mesa, comanda, venda ou Delivery.
String numeroPedidoParaImpressao(Object? valor, {Object? alternativo}) =>
    numeroPedidoOperacionalConfirmado(valor) ??
    numeroPedidoOperacionalConfirmado(alternativo) ??
    '';

String exigirNumeroPedidoOperacional(Object? valor) {
  final numero = numeroPedidoOperacionalConfirmado(valor);
  if (numero == null) {
    throw StateError(
      'Aguarde o servidor confirmar o número do pedido antes de imprimir.',
    );
  }
  return numero;
}
