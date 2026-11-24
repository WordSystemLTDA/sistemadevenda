import 'dart:async';

/// Executa a primeira leitura imediatamente e agrupa os eventos recebidos
/// durante a consulta em uma nova leitura com os parametros mais recentes.
/// Nao armazena respostas: toda execucao consulta novamente o servidor.
class AtualizacaoAgrupada {
  AtualizacaoAgrupada({this.intervaloMinimo = Duration.zero}) {
    if (intervaloMinimo < Duration.zero) {
      throw ArgumentError.value(intervaloMinimo, 'intervaloMinimo');
    }
  }

  final Duration intervaloMinimo;
  Timer? _intervalo;
  Completer<void>? _liberarIntervalo;
  Future<void>? _execucao;
  Future<void> Function()? _pendente;
  bool _descartada = false;

  bool get emAndamento => _execucao != null;

  Future<void> executar(Future<void> Function() atualizar) {
    if (_descartada) return Future.value();
    _pendente = atualizar;
    final atual = _execucao;
    if (atual != null) return atual;
    final conclusao = Completer<void>();
    _execucao = conclusao.future;
    unawaited(_processar(conclusao));
    return conclusao.future;
  }

  Future<void> _processar(Completer<void> conclusao) async {
    Object? falha;
    StackTrace? pilha;
    while (!_descartada && _pendente != null) {
      // Mantem a ultima atualizacao mesmo durante uma rajada prolongada.
      final espera = _liberarIntervalo;
      if (espera != null && !espera.isCompleted) await espera.future;
      if (_descartada) break;
      final atualizar = _pendente!;
      _pendente = null;
      if (intervaloMinimo > Duration.zero) {
        final liberar = _liberarIntervalo = Completer<void>();
        _intervalo = Timer(intervaloMinimo, () => liberar.complete());
      }
      try {
        await atualizar();
        falha = null;
        pilha = null;
      } catch (erro, stack) {
        falha = erro;
        pilha = stack;
      }
    }
    _execucao = null;
    if (falha != null) {
      conclusao.completeError(falha, pilha);
    } else {
      conclusao.complete();
    }
  }

  void dispose() {
    _descartada = true;
    _pendente = null;
    _intervalo?.cancel();
    final liberar = _liberarIntervalo;
    if (liberar != null && !liberar.isCompleted) liberar.complete();
  }
}
