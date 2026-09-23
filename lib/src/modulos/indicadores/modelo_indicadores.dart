import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';

bool podeVerIndicadores(UsuarioModelo? usuario) =>
    ['0', '1'].contains(usuario?.nivel?.trim());

const int horaInicioDiaOperacionalIndicadores = 5;

DateTime dataOperacionalIndicadores(DateTime agora) {
  final data = DateTime(agora.year, agora.month, agora.day);
  return agora.hour < horaInicioDiaOperacionalIndicadores
      ? data.subtract(const Duration(days: 1))
      : data;
}

// Dias civis nao devem perder uma coluna em periodos historicos com horario de verao.
int diasEntreDatas(DateTime inicio, DateTime fim) =>
    DateTime.utc(fim.year, fim.month, fim.day)
        .difference(DateTime.utc(inicio.year, inicio.month, inicio.day))
        .inDays;

/// Sem uma base positiva, a variação não é comparável.
double? variacaoPercentualIndicadores(num atual, num anterior) {
  if (!atual.isFinite || !anterior.isFinite || anterior <= 0) return null;
  return (atual - anterior) / anterior * 100;
}

String _normalizarStatus(String status) => status
    .trim()
    .toLowerCase()
    .replaceAll('í', 'i')
    .replaceAll('ú', 'u')
    .replaceAll('ã', 'a');

class MetasIndicadores {
  const MetasIndicadores({
    this.consumoDiarioCentavos = 0,
    this.atendimentosDiarios = 0,
    this.ticketMedioCentavos = 0,
  });

  factory MetasIndicadores.fromMap(Map<String, dynamic> map) {
    int valor(String campo) {
      final item = map[campo] ?? 0;
      if (item is! int || item < 0) {
        throw const FormatException('Metas inválidas.');
      }
      return item;
    }

    return MetasIndicadores(
      consumoDiarioCentavos: valor('consumo_diario_centavos'),
      atendimentosDiarios: valor('atendimentos_diarios'),
      ticketMedioCentavos: valor('ticket_medio_centavos'),
    );
  }

  final int consumoDiarioCentavos;
  final int atendimentosDiarios;
  final int ticketMedioCentavos;

  bool get configuradas =>
      consumoDiarioCentavos > 0 ||
      atendimentosDiarios > 0 ||
      ticketMedioCentavos > 0;

  Map<String, int> toMap() => {
        'consumo_diario_centavos': consumoDiarioCentavos,
        'atendimentos_diarios': atendimentosDiarios,
        'ticket_medio_centavos': ticketMedioCentavos,
      };
}

class ProdutoIndicadores {
  ProdutoIndicadores.fromMap(Map<String, dynamic> map)
      : id = map['id'].toString(),
        nome = map['nome'] as String,
        canal = map['canal'] as String,
        quantidade = (map['quantidade'] as num).toDouble(),
        consumoCentavos = map['consumo_centavos'] as int {
    if (!quantidade.isFinite || quantidade < 0) {
      throw const FormatException('Quantidade de produto inválida.');
    }
  }

  final String id;
  final String nome;
  final String canal;
  final double quantidade;
  final int consumoCentavos;
}

enum CanalIndicadores {
  todos('Todos', ''),
  mesa('Mesas', 'Mesa'),
  comanda('Comandas', 'Comanda'),
  balcao('Balcão', 'Balcao');

  const CanalIndicadores(this.rotulo, this.codigo);
  final String rotulo;
  final String codigo;
}

class GrupoIndicadores {
  GrupoIndicadores.fromMap(Map<String, dynamic> map)
      : dia = DateTime.parse(map['dia'] as String),
        hora = map['hora'] as int?,
        canal = map['canal'] as String,
        status = map['status'] as String,
        quantidade = map['quantidade'] as int,
        consumoCentavos = map['consumo_centavos'] as int {
    if (quantidade < 0 || (hora != null && (hora! < 0 || hora! > 23))) {
      throw const FormatException('Indicadores inválidos.');
    }
  }
  final DateTime dia;
  final int? hora;
  final String canal;
  final String status;
  final int quantidade;
  final int consumoCentavos;
  bool get cancelado =>
      const {'cancelada', 'cancelado'}.contains(_normalizarStatus(status));
  bool get finalizado => const {
        'finalizada',
        'finalizado',
        'concluida',
        'concluido',
        'fechada',
        'fechado',
        'encerrada',
        'encerrado',
      }.contains(_normalizarStatus(status));
}

class ModeloIndicadores {
  ModeloIndicadores.fromMap(Map<String, dynamic> map, {this.offline = false})
      : inicio = DateTime.parse(map['inicio'] as String),
        fim = DateTime.parse(map['fim'] as String),
        atualizadoEm = DateTime.parse(map['atualizado_em'] as String),
        escopo = map['escopo'] as String? ?? 'empresa',
        criterioPessoal = map['criterio_pessoal'] as String? ??
            'Atendimentos registrados pelo seu usuário.',
        suporteMetas = map['suporte_metas'] == true,
        metas = map['metas'] is Map
            ? MetasIndicadores.fromMap(Map<String, dynamic>.from(map['metas']))
            : null,
        comparacao = map['comparacao'] is Map
            ? ModeloIndicadores.fromMap({
                'versao': 1,
                'atualizado_em': map['atualizado_em'],
                'escopo': map['escopo'] ?? 'empresa',
                ...Map<String, dynamic>.from(map['comparacao']),
              }, offline: offline)
            : null,
        produtos = (map['produtos'] as List? ?? const [])
            .map((item) =>
                ProdutoIndicadores.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false),
        grupos = (map['grupos'] as List)
            .map((item) =>
                GrupoIndicadores.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false) {
    if (map['versao'] != 1 ||
        !const {'empresa', 'pessoal'}.contains(escopo) ||
        fim.isBefore(inicio) ||
        diasEntreDatas(inicio, fim) >= 90) {
      throw const FormatException('Versão ou período inválido.');
    }
  }
  final DateTime inicio;
  final DateTime fim;
  final DateTime atualizadoEm;
  final bool offline;
  final String escopo;
  final String criterioPessoal;
  final bool suporteMetas;
  final MetasIndicadores? metas;
  final ModeloIndicadores? comparacao;
  final List<ProdutoIndicadores> produtos;
  final List<GrupoIndicadores> grupos;

  bool get pessoal => escopo == 'pessoal';
  int get diasNoPeriodo => diasEntreDatas(inicio, fim) + 1;

  ResumoIndicadores? resumirComparacao(CanalIndicadores canal) =>
      comparacao?.resumir(canal);

  List<ProdutoIndicadores> produtosDoCanal(CanalIndicadores canal) => produtos
      .where((p) => canal == CanalIndicadores.todos || p.canal == canal.codigo)
      .toList(growable: false);

  ResumoIndicadores resumir(CanalIndicadores canal) => ResumoIndicadores(
      this,
      grupos
          .where(
              (g) => canal == CanalIndicadores.todos || g.canal == canal.codigo)
          .toList());
}

class PontoIndicadores {
  const PontoIndicadores(this.posicao, this.quantidade,
      {this.consumoCentavos = 0});
  final int posicao;
  final int quantidade;
  final int consumoCentavos;
}

class ResumoIndicadores {
  ResumoIndicadores(this.modelo, this.grupos);
  final ModeloIndicadores modelo;
  final List<GrupoIndicadores> grupos;
  Iterable<GrupoIndicadores> get validos => grupos.where((g) => !g.cancelado);
  int get quantidade => validos.fold(0, (soma, g) => soma + g.quantidade);
  int get consumoCentavos =>
      validos.fold(0, (soma, g) => soma + g.consumoCentavos);
  int get ticketMedioCentavos =>
      quantidade > 0 ? (consumoCentavos / quantidade).round() : 0;
  int get diasNoPeriodo => modelo.diasNoPeriodo;
  int get cancelados => grupos
      .where((g) => g.cancelado)
      .fold(0, (soma, g) => soma + g.quantidade);
  int get totalAtendimentos => quantidade + cancelados;
  double get taxaCancelamento =>
      totalAtendimentos > 0 ? cancelados / totalAtendimentos * 100 : 0;
  int get finalizados => validos
      .where((g) => g.finalizado)
      .fold(0, (soma, g) => soma + g.quantidade);
  int get emAndamento => validos
      .where((g) => g.canal != 'Balcao' && g.status == 'Andamento')
      .fold(0, (soma, g) => soma + g.quantidade);
  int get emFechamento => validos
      .where((g) => g.canal != 'Balcao' && g.status == 'Fechamento')
      .fold(0, (soma, g) => soma + g.quantidade);
  List<PontoIndicadores> _agrupar(
      int tamanho, int? Function(GrupoIndicadores) posicao) {
    final quantidades = List<int>.filled(tamanho, 0);
    final consumos = List<int>.filled(tamanho, 0);
    for (final grupo in validos) {
      final indice = posicao(grupo);
      if (indice == null || indice < 0 || indice >= tamanho) continue;
      quantidades[indice] += grupo.quantidade;
      consumos[indice] += grupo.consumoCentavos;
    }
    return List.generate(
        tamanho,
        (indice) => PontoIndicadores(indice, quantidades[indice],
            consumoCentavos: consumos[indice]));
  }

  List<PontoIndicadores> get porHora => _agrupar(24, (g) => g.hora);
  List<PontoIndicadores> get porHoraOperacional {
    final horas = porHora;
    return [
      ...horas.skip(horaInicioDiaOperacionalIndicadores),
      ...horas.take(horaInicioDiaOperacionalIndicadores),
    ];
  }

  List<PontoIndicadores> get porDia =>
      _agrupar(diasNoPeriodo, (g) => diasEntreDatas(modelo.inicio, g.dia));
  PontoIndicadores? get pico {
    PontoIndicadores? maior;
    for (final ponto in porHora) {
      if (ponto.quantidade > (maior?.quantidade ?? 0)) maior = ponto;
    }
    return maior;
  }
}
