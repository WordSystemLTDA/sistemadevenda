/// Apenas o adiamento explicito do protocolo de sincronizacao e uma pausa
/// esperada. HTTP 503 generico e falhas em outras rotas continuam sendo erros.
bool ehAdiamentoSincronizacao(
    {required String caminho,
    required int? status,
    required Object? resposta}) {
  final rota = Uri.tryParse(caminho)?.path ?? caminho;
  if (!RegExp(
          r'(^|/)sincronizador(?:_de_arquivos/(enviar_arquivos|receber_upload)|/transferir)\.php$')
      .hasMatch(rota)) {
    return false;
  }
  if (![200, 429, 503].contains(status) || resposta is! Map) return false;
  final espera = int.tryParse('${resposta['tentar_apos']}') ?? 0;
  return resposta['protocolo'] == 2 &&
      resposta['sucesso'] == false &&
      resposta['codigo'] == 'SINCRONIZACAO_ADIADA' &&
      resposta['status'] == 'pendente' &&
      espera > 0 &&
      espera <= 3600;
}
