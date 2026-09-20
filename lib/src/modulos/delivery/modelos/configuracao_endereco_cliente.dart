class ConfiguracaoEnderecoCliente {
  final String cep;
  final String cidade;
  final String uf;
  final bool bloquearCidade;
  final bool enderecoObrigatorio;

  const ConfiguracaoEnderecoCliente({
    this.cep = '',
    this.cidade = '',
    this.uf = '',
    this.bloquearCidade = false,
    this.enderecoObrigatorio = true,
  });

  factory ConfiguracaoEnderecoCliente.fromResposta(dynamic resposta) {
    final dados = switch (resposta) {
      Map valor => Map<String, dynamic>.from(valor),
      List valor when valor.isNotEmpty && valor.first is Map =>
        Map<String, dynamic>.from(valor.first as Map),
      _ => <String, dynamic>{},
    };
    final requerido = _texto(
        dados, ['requerido_endereco', 'requeridoEndereco', 'endereco']);
    return ConfiguracaoEnderecoCliente(
      cep: _texto(dados, ['padrao_cep', 'padraoCep']),
      cidade:
          _texto(dados, ['padrao_nome_cidade', 'padraoNomeCidade']),
      uf: _texto(dados, ['padrao_estado', 'padraoEstado']).toUpperCase(),
      bloquearCidade: _ativo(_texto(
          dados, ['bloquear_edicao_cidade', 'bloquearEdicaoCidade'])),
      enderecoObrigatorio: requerido.isEmpty || _ativo(requerido),
    );
  }

  static String _texto(Map<String, dynamic> dados, List<String> chaves) {
    for (final chave in chaves) {
      final valor = dados[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  static bool _ativo(Object? valor) {
    final texto = valor?.toString().trim().toLowerCase() ?? '';
    return texto == 'sim' ||
        texto == 's' ||
        texto == '1' ||
        texto == 'true';
  }
}
