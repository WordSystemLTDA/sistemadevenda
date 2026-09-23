/// Uma resposta perdida nao significa que o servidor recusou a operacao.
/// Nunca devolver ao carrinho/alterar o payload de um envio de resultado incerto.
class SegurancaPendencias {
  static bool conflitoDefinitivo(Map<String, Object?> op) {
    if (op['estado'] != 'conflito') return false;
    if (const {
      'atendimento_encerrado',
      'atendimento_alterado',
      'atendimento_transferido',
      'recurso_reutilizado',
      'operacao_id_reutilizado',
      'origem_nao_confirmada',
    }.contains(op['codigo_erro'])) {
      return true;
    }
    // Compatibilidade com pendencias gravadas antes dos codigos estruturados.
    final erro = '${op['erro'] ?? ''}'.toLowerCase();
    return RegExp('encerrad|finalizad|transferid|reutilizad|outro atendimento|'
            'abertura original|venda original|identidade do atendimento')
        .hasMatch(erro);
  }

  static bool podeRecuperar(Map<String, Object?> op) =>
      ['produtos', 'venda'].contains(op['acao']) &&
      !conflitoDefinitivo(op) &&
      (op['estado'] == 'conflito' ||
          op['estado'] == 'pendente' && op['tentativas'] == 0) &&
      (op['resposta'] == null || op['resposta'] == '');
}
