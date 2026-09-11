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
  }) async {
    if (concluido) return true;
    if (_executando) return false;
    _executando = true;
    try {
      if (!pedidoRegistrado) {
        _mensagens = List.unmodifiable(prepararImpressao());
        pedidoRegistrado = await registrarPedido();
        if (!pedidoRegistrado) return false;
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
