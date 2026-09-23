import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Nao guarda respostas: apenas impede o preparo offline de ocupar todas as
/// conexoes enquanto o usuario consulta uma tela ou envia um pedido.
class AdaptadorHttpPrioritario implements HttpClientAdapter {
  final HttpClientAdapter transporte;
  final Duration respiro;
  final _fila = Queue<_ConsultaPreparacao>();
  final _liberacoesAtivas = <void Function()>{};
  int _interativas = 0;
  bool _preparando = false;
  bool _fechado = false;
  Timer? _retomada;

  AdaptadorHttpPrioritario(this.transporte,
      {this.respiro = const Duration(milliseconds: 120)});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    if (_fechado) throw _cancelamento(options);
    final preparacao =
        options.method == 'GET' && options.extra['preparacaoOffline'] == true;
    if (preparacao) {
      final consulta = _ConsultaPreparacao(options);
      _fila.add(consulta);
      cancelFuture?.then((_) => _cancelar(consulta),
          onError: (Object _, StackTrace __) => _cancelar(consulta));
      _drenar();
      await consulta.vez.future;
    } else {
      _retomada?.cancel();
      _retomada = null;
      _interativas++;
    }
    var liberada = false;
    void liberar() {
      if (liberada) return;
      liberada = true;
      _liberacoesAtivas.remove(liberar);
      if (preparacao) {
        _preparando = false;
      } else {
        _interativas--;
      }
      // Uma pequena janela permite a proxima consulta da tela entrar primeiro.
      _retomada?.cancel();
      if (!_fechado) {
        _retomada = Timer(respiro, () {
          _retomada = null;
          _drenar();
        });
      }
    }

    _liberacoesAtivas.add(liberar);
    cancelFuture?.then((_) => liberar(),
        onError: (Object _, StackTrace __) => liberar());
    try {
      final resposta =
          await transporte.fetch(options, requestStream, cancelFuture);
      if (!options.receiveDataWhenStatusError &&
          !options.validateStatus(resposta.statusCode)) {
        // Nesse modo o Dio fecha a resposta sem assinar seu corpo.
        liberar();
        return resposta;
      }
      // fetch termina nos cabecalhos. A conexao continua ocupada enquanto o
      // corpo chega; nao consumir antecipadamente nem substituir ResponseBody
      // (extra, headers e onClose pertencem ao adaptador/Dio).
      final origem = resposta.stream;
      StreamSubscription<Uint8List>? assinatura;
      late final StreamController<Uint8List> corpo;
      corpo = StreamController<Uint8List>(
        sync: true,
        onListen: () {
          assinatura = origem.listen(
            corpo.add,
            onError: (Object erro, StackTrace stack) {
              liberar();
              corpo.addError(erro, stack);
            },
            onDone: () {
              liberar();
              unawaited(corpo.close());
            },
          );
        },
        onPause: () => assinatura?.pause(),
        onResume: () => assinatura?.resume(),
        onCancel: () async {
          try {
            await assinatura?.cancel();
          } finally {
            liberar();
          }
        },
      );
      resposta.stream = corpo.stream;
      return resposta;
    } catch (_) {
      liberar();
      rethrow;
    }
  }

  DioException _cancelamento(RequestOptions options) => DioException(
      requestOptions: options,
      type: DioExceptionType.cancel,
      message: 'Consulta de preparo cancelada.');

  void _cancelar(_ConsultaPreparacao consulta) {
    if (consulta.vez.isCompleted) return;
    _fila.remove(consulta);
    consulta.vez.completeError(_cancelamento(consulta.options));
  }

  void _drenar() {
    if (_fechado ||
        _retomada != null ||
        _preparando ||
        _interativas > 0 ||
        _fila.isEmpty) {
      return;
    }
    final consulta = _fila.removeFirst();
    _preparando = true;
    consulta.vez.complete();
  }

  @override
  void close({bool force = false}) {
    _fechado = true;
    _retomada?.cancel();
    _retomada = null;
    for (final consulta in _fila.toList()) {
      _cancelar(consulta);
    }
    for (final liberar in _liberacoesAtivas.toList()) {
      liberar();
    }
    transporte.close(force: force);
  }
}

class _ConsultaPreparacao {
  final RequestOptions options;
  final vez = Completer<void>();
  _ConsultaPreparacao(this.options);
}
