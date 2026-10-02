class ClienteCadastro {
  const ClienteCadastro({
    required this.id,
    required this.nome,
    required this.celular,
    required this.email,
    required this.observacao,
    required this.dadosOriginais,
  });

  final String id;
  final String nome;
  final String celular;
  final String email;
  final String observacao;
  final Map<String, dynamic> dadosOriginais;

  factory ClienteCadastro.fromMap(Map<String, dynamic> dados) {
    return ClienteCadastro(
      id: _valor(dados, const ['id']),
      nome: _valor(dados, const [
        'nome_puro',
        'nomePuro',
        'nomeCliente',
        'nomecliente',
        'nome',
      ]),
      celular: _valor(dados, const ['celular', 'telefone', 'celularCliente']),
      email: _valor(dados, const ['email', 'e-mail']),
      observacao: _valor(dados, const ['obs', 'observacao']),
      dadosOriginais: Map<String, dynamic>.from(dados),
    );
  }

  Map<String, dynamic> get dadosFormulario => {
        ...dadosOriginais,
        'id': id,
        'nome_puro': nome,
        'celular': celular,
        'email': email,
        'obs': observacao,
      };

  String get inicial {
    final texto = nome.trim();
    return texto.isEmpty ? '?' : texto.substring(0, 1).toUpperCase();
  }

  static String _valor(Map<String, dynamic> dados, List<String> chaves) {
    for (final chave in chaves) {
      final valor = dados[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }
}

class EnderecoClienteCadastro {
  const EnderecoClienteCadastro({
    required this.id,
    required this.endereco,
    required this.numero,
    required this.complemento,
    required this.bairro,
    required this.cidade,
    required this.uf,
    required this.cep,
    required this.padrao,
    required this.sitio,
    required this.dadosOriginais,
  });

  final String id;
  final String endereco;
  final String numero;
  final String complemento;
  final String bairro;
  final String cidade;
  final String uf;
  final String cep;
  final bool padrao;
  final bool sitio;
  final Map<String, dynamic> dadosOriginais;

  factory EnderecoClienteCadastro.fromMap(Map<String, dynamic> dados) {
    final tipoLocal = _valor(dados, const ['tipolocalentrega']);
    return EnderecoClienteCadastro(
      id: _valor(dados, const ['id']),
      endereco: _valor(dados, const ['endereco']),
      numero: _valor(dados, const ['numero']),
      complemento: _valor(dados, const ['complemento']),
      bairro: _valor(dados, const ['bairro']),
      cidade: _valor(dados, const ['cidade']),
      uf: _valor(dados, const ['estado', 'uf']),
      cep: _valor(dados, const ['cep']),
      padrao: _valorAtivo(dados['padrao']),
      sitio: tipoLocal.toLowerCase() == 'sitio' ||
          tipoLocal.toLowerCase() == 'sítio',
      dadosOriginais: Map<String, dynamic>.from(dados),
    );
  }

  String get linhaPrincipal {
    final partes = [endereco, numero]
        .map((valor) => valor.trim())
        .where((valor) => valor.isNotEmpty)
        .toList(growable: false);
    return partes.isEmpty ? 'Endereço sem rua informada' : partes.join(', ');
  }

  String get linhaSecundaria {
    final localidade = [bairro, cidade, uf]
        .map((valor) => valor.trim())
        .where((valor) => valor.isNotEmpty)
        .join(' · ');
    final detalhes = [
      if (complemento.trim().isNotEmpty) complemento.trim(),
      if (cep.trim().isNotEmpty) 'CEP ${cep.trim()}',
    ].join(' · ');
    if (localidade.isEmpty) return detalhes;
    if (detalhes.isEmpty) return localidade;
    return '$localidade\n$detalhes';
  }

  static String _valor(Map<String, dynamic> dados, List<String> chaves) {
    for (final chave in chaves) {
      final valor = dados[chave]?.toString().trim() ?? '';
      if (valor.isNotEmpty) return valor;
    }
    return '';
  }

  static bool _valorAtivo(Object? valor) {
    final texto = valor?.toString().trim().toLowerCase() ?? '';
    return texto == 'sim' || texto == 's' || texto == '1' || texto == 'true';
  }
}
