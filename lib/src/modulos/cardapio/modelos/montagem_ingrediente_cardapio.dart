enum AcaoIngredienteCardapio {
  sem('Sem'),
  pouco('Pouco'),
  normal('Normal'),
  mais('Mais'),
  trocar('Trocar');

  final String rotulo;

  const AcaoIngredienteCardapio(this.rotulo);
}

bool tituloIngredientesCardapio(Object? titulo) {
  final texto = (titulo ?? '').toString().trim().toLowerCase();
  return texto.contains('ingredientes do cardápio') ||
      texto.contains('ingredientes do cardapio');
}

class MontagemIngredienteCardapio {
  static const String rotuloEmbalagemSeparada = 'Embalar Separado';

  final String nomeOriginal;
  final AcaoIngredienteCardapio acao;
  final String? destinoId;
  final String? destinoNome;
  final String? destinoTipo;
  final int quantidadeTroca;
  final bool separado;
  final String valorEmbalagemSeparada;

  const MontagemIngredienteCardapio({
    required this.nomeOriginal,
    this.acao = AcaoIngredienteCardapio.normal,
    this.destinoId,
    this.destinoNome,
    this.destinoTipo,
    this.quantidadeTroca = 1,
    this.separado = false,
    this.valorEmbalagemSeparada = '0.00',
  });

  bool get possuiAlteracao =>
      acao != AcaoIngredienteCardapio.normal || separado;

  static MontagemIngredienteCardapio? inferirAlteracao(String descricao) {
    var texto = descricao.trim();
    if (texto.isEmpty) return null;

    final marcadorSeparado = RegExp(
      r'\s*\(SEPARADO\)\s*$',
      caseSensitive: false,
    );
    final separado = marcadorSeparado.hasMatch(texto);
    texto = texto.replaceFirst(marcadorSeparado, '').trim();

    final troca = RegExp(
      r'^TROCAR\s+(.+?)\s+POR\s+(\d+)\s*[xX]\s+(.+)$',
      caseSensitive: false,
    ).firstMatch(texto);
    if (troca != null) {
      return MontagemIngredienteCardapio(
        nomeOriginal: troca.group(1)!.trim(),
        acao: AcaoIngredienteCardapio.trocar,
        destinoNome: troca.group(3)!.trim(),
        quantidadeTroca: int.tryParse(troca.group(2)!) ?? 1,
        separado: separado,
      );
    }

    for (final entrada in <(RegExp, AcaoIngredienteCardapio)>[
      (
        RegExp(r'^SEM\s+(.+)$', caseSensitive: false),
        AcaoIngredienteCardapio.sem
      ),
      (
        RegExp(r'^(?:POUCO|MENOS)\s+(.+)$', caseSensitive: false),
        AcaoIngredienteCardapio.pouco
      ),
      (
        RegExp(r'^MAIS\s+(.+)$', caseSensitive: false),
        AcaoIngredienteCardapio.mais
      ),
    ]) {
      final resultado = entrada.$1.firstMatch(texto);
      if (resultado != null) {
        return MontagemIngredienteCardapio(
          nomeOriginal: resultado.group(1)!.trim(),
          acao: entrada.$2,
          separado: separado,
        );
      }
    }

    return separado
        ? MontagemIngredienteCardapio(
            nomeOriginal: texto,
            separado: true,
          )
        : null;
  }

  MontagemIngredienteCardapio copyWith({
    String? nomeOriginal,
    AcaoIngredienteCardapio? acao,
    String? destinoId,
    String? destinoNome,
    String? destinoTipo,
    int? quantidadeTroca,
    bool? separado,
    String? valorEmbalagemSeparada,
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
      valorEmbalagemSeparada:
          valorEmbalagemSeparada ?? this.valorEmbalagemSeparada,
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

    if (texto == null) return separado ? rotuloEmbalagemSeparada : null;
    return separado && acao != AcaoIngredienteCardapio.sem
        ? '$texto - $rotuloEmbalagemSeparada'
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
      'valorEmbalagemSeparada': valorEmbalagemSeparada,
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
      valorEmbalagemSeparada: (map['valorEmbalagemSeparada'] ??
              map['valor_embalagem_separada'] ??
              '0.00')
          .toString(),
    );
  }

  static bool _parseBool(Object? valor) {
    if (valor is bool) return valor;
    final texto = valor?.toString().trim().toLowerCase() ?? '';
    return texto == '1' || texto == 'true' || texto == 'sim';
  }
}
