String nomeClienteAtendimento(String? nome, String? observacao,
    {String vazio = 'Sem cliente'}) {
  final cliente = nome?.trim() ?? '';
  if (cliente.isNotEmpty && cliente.toLowerCase() != 'sem cliente') {
    return cliente;
  }
  final identificacao = observacao?.trim() ?? '';
  return identificacao.isEmpty ? vazio : identificacao;
}
