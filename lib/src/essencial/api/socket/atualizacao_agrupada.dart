import 'dart:async';

/// Executa a primeira leitura imediatamente e agrupa os eventos recebidos
/// durante a consulta em uma nova leitura com os parametros mais recentes.
/// Nao armazena respostas: toda execucao consulta novamente o servidor.
class AtualizacaoAgrupada {
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
      final atualizar = _pendente!;
      _pendente = null;
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
  }
}
