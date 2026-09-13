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
  bool get cancelado => status == 'Cancelada';
}

class ModeloIndicadores {
  ModeloIndicadores.fromMap(Map<String, dynamic> map, {this.offline = false})
      : inicio = DateTime.parse(map['inicio'] as String),
        fim = DateTime.parse(map['fim'] as String),
        atualizadoEm = DateTime.parse(map['atualizado_em'] as String),
        grupos = (map['grupos'] as List)
            .map((item) =>
                GrupoIndicadores.fromMap(Map<String, dynamic>.from(item)))
            .toList(growable: false) {
    if (map['versao'] != 1 ||
        fim.isBefore(inicio) ||
        diasEntreDatas(inicio, fim) >= 90) {
      throw const FormatException('Versão ou período inválido.');
    }
  }
  final DateTime inicio;
  final DateTime fim;
  final DateTime atualizadoEm;
  final bool offline;
  final List<GrupoIndicadores> grupos;

  ResumoIndicadores resumir(CanalIndicadores canal) => ResumoIndicadores(
      this,
      grupos
          .where(
              (g) => canal == CanalIndicadores.todos || g.canal == canal.codigo)
          .toList());
}

class PontoIndicadores {
  const PontoIndicadores(this.posicao, this.quantidade);
  final int posicao;
  final int quantidade;
}

class ResumoIndicadores {
  ResumoIndicadores(this.modelo, this.grupos);
  final ModeloIndicadores modelo;
  final List<GrupoIndicadores> grupos;
  Iterable<GrupoIndicadores> get validos => grupos.where((g) => !g.cancelado);
  int get quantidade => validos.fold(0, (soma, g) => soma + g.quantidade);
  int get consumoCentavos =>
      validos.fold(0, (soma, g) => soma + g.consumoCentavos);
  int get cancelados => grupos
      .where((g) => g.cancelado)
      .fold(0, (soma, g) => soma + g.quantidade);
  int get emAndamento => validos
      .where((g) => g.canal != 'Balcao' && g.status == 'Andamento')
      .fold(0, (soma, g) => soma + g.quantidade);
  int get emFechamento => validos
      .where((g) => g.canal != 'Balcao' && g.status == 'Fechamento')
      .fold(0, (soma, g) => soma + g.quantidade);
  List<PontoIndicadores> get porHora => List.generate(
      24,
      (hora) => PontoIndicadores(
          hora,
          validos
              .where((g) => g.hora == hora)
              .fold(0, (soma, g) => soma + g.quantidade)));
  List<PontoIndicadores> get porDia => List.generate(
      diasEntreDatas(modelo.inicio, modelo.fim) + 1,
      (dia) => PontoIndicadores(
          dia,
          validos
              .where((g) => diasEntreDatas(modelo.inicio, g.dia) == dia)
              .fold(0, (soma, g) => soma + g.quantidade)));
  PontoIndicadores? get pico {
    PontoIndicadores? maior;
    for (final ponto in porHora) {
      if (ponto.quantidade > (maior?.quantidade ?? 0)) maior = ponto;
    }
    return maior;
  }
}
