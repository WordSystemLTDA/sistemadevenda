class FinalizacaoComPreparo {
  bool pedidoRegistrado = false;
  bool concluido = false;
  bool _impressaoRegistrada = false;
  bool _executando = false;
  List<String>? _mensagens;

  Future<bool> executar({
    required List<String> Function() prepararImpressao,
    required Future<bool> Function() registrarPedido,
    required Future<void> Function(List<String>) enviarImpressao,
    required Future<void> Function() limparCarrinho,
    Future<void> Function(List<String>)? salvarImpressaoAntesDoPedido,
    Future<void> Function(List<String>)? cancelarImpressaoPreparada,
    Future<void> Function(List<String>)? registrarPedidoDuravel,
  }) async {
    if (concluido) return true;
    if (_executando) return false;
    _executando = true;
    try {
      if (registrarPedidoDuravel != null) {
        _mensagens = List.unmodifiable(prepararImpressao());
        await registrarPedidoDuravel(_mensagens!);
        pedidoRegistrado = true;
        concluido = true;
        return true;
      }
      if (!pedidoRegistrado) {
        _mensagens = List.unmodifiable(prepararImpressao());
        // O comprovante sobrevive ao fechamento do app durante a chamada HTTP.
        // A fila so o libera para envio depois de confirmar o registro do pedido.
        await salvarImpressaoAntesDoPedido?.call(_mensagens!);
        pedidoRegistrado = await registrarPedido();
        if (!pedidoRegistrado) {
          await cancelarImpressaoPreparada?.call(_mensagens!);
          return false;
        }
      }
      if (!_impressaoRegistrada) {
        await enviarImpressao(_mensagens!);
        _impressaoRegistrada = true;
      }
      await limparCarrinho();
      concluido = true;
      return true;
    } finally {
      _executando = false;
    }
  }
}
