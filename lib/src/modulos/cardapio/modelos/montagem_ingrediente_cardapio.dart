enum AcaoIngredienteCardapio {
  sem('Sem'),
  pouco('Pouco'),
  normal('Normal'),
  mais('Mais'),
  trocar('Trocar');

  final String rotulo;

  const AcaoIngredienteCardapio(this.rotulo);
}

class MontagemIngredienteCardapio {
  final String nomeOriginal;
  final AcaoIngredienteCardapio acao;
  final String? destinoId;
  final String? destinoNome;
  final String? destinoTipo;
  final int quantidadeTroca;
  final bool separado;

  const MontagemIngredienteCardapio({
    required this.nomeOriginal,
    this.acao = AcaoIngredienteCardapio.normal,
    this.destinoId,
    this.destinoNome,
    this.destinoTipo,
    this.quantidadeTroca = 1,
    this.separado = false,
  });

  bool get possuiAlteracao =>
      acao != AcaoIngredienteCardapio.normal || separado;

  MontagemIngredienteCardapio copyWith({
    String? nomeOriginal,
    AcaoIngredienteCardapio? acao,
    String? destinoId,
    String? destinoNome,
    String? destinoTipo,
    int? quantidadeTroca,
    bool? separado,
    bool limparDestino = false,
  }) {
    return MontagemIngredienteCardapio(
      nomeOriginal: nomeOriginal ?? this.nomeOriginal,
      acao: acao ?? this.acao,
      destinoId: limparDestino ? null : destinoId ?? this.destinoId,
      destinoNome: limparDestino ? null : destinoNome ?? this.destinoNome,
      destinoTipo: limparDestino ? null : destinoTipo ?? this.destinoTipo,
      quantidadeTroca: quantidadeTroca ?? this.quantidadeTroca,
      separado: separado ?? this.separado,
    );
  }

  String get descricao {
    final texto = switch (acao) {
      AcaoIngredienteCardapio.normal => nomeOriginal,
      AcaoIngredienteCardapio.sem => 'SEM $nomeOriginal',
      AcaoIngredienteCardapio.pouco => 'POUCO $nomeOriginal',
      AcaoIngredienteCardapio.mais => 'MAIS $nomeOriginal',
      AcaoIngredienteCardapio.trocar =>
        'TROCAR $nomeOriginal POR ${quantidadeTroca}x ${destinoNome ?? ''}',
    };

    if (separado && acao != AcaoIngredienteCardapio.sem) {
      return '$texto (SEPARADO)';
    }
    return texto;
  }

  String? get detalheVisualizacao {
    final texto = switch (acao) {
      AcaoIngredienteCardapio.normal => null,
      AcaoIngredienteCardapio.sem => 'Sem',
      AcaoIngredienteCardapio.pouco => 'Pouco',
      AcaoIngredienteCardapio.mais => 'Mais',
      AcaoIngredienteCardapio.trocar =>
        'Trocar por ${quantidadeTroca}x ${destinoNome ?? ''}',
    };

    if (texto == null) return separado ? 'Embalar separado' : null;
    return separado && acao != AcaoIngredienteCardapio.sem
        ? '$texto - Embalar separado'
        : texto;
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'versao': 1,
      'nomeOriginal': nomeOriginal,
      'acao': acao.name,
      'destinoId': destinoId,
      'destinoNome': destinoNome,
      'destinoTipo': destinoTipo,
      'quantidadeTroca': quantidadeTroca,
      'separado': separado,
    };
  }

  factory MontagemIngredienteCardapio.fromMap(Map<String, dynamic> map) {
    final acaoTexto = map['acao']?.toString() ?? 'normal';
    final acao = AcaoIngredienteCardapio.values
            .where((item) => item.name == acaoTexto)
            .firstOrNull ??
        AcaoIngredienteCardapio.normal;

    return MontagemIngredienteCardapio(
      nomeOriginal: map['nomeOriginal']?.toString() ??
          map['nome_original']?.toString() ??
          '',
      acao: acao,
      destinoId: map['destinoId']?.toString() ?? map['destino_id']?.toString(),
      destinoNome:
          map['destinoNome']?.toString() ?? map['destino_nome']?.toString(),
      destinoTipo:
          map['destinoTipo']?.toString() ?? map['destino_tipo']?.toString(),
      quantidadeTroca: int.tryParse(
              (map['quantidadeTroca'] ?? map['quantidade_troca'] ?? 1)
                  .toString()) ??
          1,
      separado: _parseBool(map['separado'] ?? map['embalar_separado']),
    );
  }

  static bool _parseBool(Object? valor) {
    if (valor is bool) return valor;
    final texto = valor?.toString().trim().toLowerCase() ?? '';
    return texto == '1' || texto == 'true' || texto == 'sim';
  }
}
