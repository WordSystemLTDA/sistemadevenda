class FinalizacaoComPreparo {
  bool pedidoRegistrado = false;
  bool concluido = false;
  bool _impressaoRegistrada = false;
  bool _executando = false;
  List<String>? _mensagens;
  Object? erroImpressao;

  Future<bool> executar({
    required List<String> Function() prepararImpressao,
    required Future<bool> Function() registrarPedido,
    required Future<void> Function(List<String>) enviarImpressao,
    required Future<void> Function() limparCarrinho,
    Future<void> Function(List<String>)? salvarImpressaoAntesDoPedido,
    Future<void> Function(List<String>)? cancelarImpressaoPreparada,
    Future<void> Function(List<String>)? registrarPedidoDuravel,
    void Function(Object erro)? aoFalharImpressao,
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
        try {
          if (_mensagens!.isNotEmpty) {
            await salvarImpressaoAntesDoPedido?.call(_mensagens!);
          }
        } catch (erro) {
          erroImpressao = erro;
          aoFalharImpressao?.call(erro);
        }
        pedidoRegistrado = await registrarPedido();
        if (!pedidoRegistrado) {
          await cancelarImpressaoPreparada?.call(_mensagens!);
          return false;
        }
      }
      if (!_impressaoRegistrada) {
        try {
          if (_mensagens!.isNotEmpty) await enviarImpressao(_mensagens!);
        } catch (erro) {
          erroImpressao = erro;
          aoFalharImpressao?.call(erro);
        }
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
