/// Evita consultas simultaneas e repeticoes rapidas de uma falha de configuracao.
class CacheDisponibilidadeVoz {
  CacheDisponibilidadeVoz({DateTime Function()? agora})
      : _agora = agora ?? DateTime.now;

  final DateTime Function() _agora;
  String? _chave;
  bool? _valor;
  DateTime? _validade;
  Future<bool>? _consulta;
  int _geracao = 0;

  Future<bool> consultar(String chave, Future<bool> Function() carregar,
      {bool forcar = false}) {
    if (chave != _chave || forcar) {
      invalidar();
      _chave = chave;
    }
    if (_valor != null && _validade?.isAfter(_agora()) == true) {
      return Future.value(_valor);
    }
    if (_consulta != null) return _consulta!;
    final geracao = _geracao;
    late final Future<bool> consulta;
    consulta = (() async {
      bool valor;
      var validade = const Duration(seconds: 30);
      try {
        valor = await carregar();
      } catch (_) {
        valor = false;
        validade = const Duration(minutes: 2);
      }
      if (geracao != _geracao) return false;
      _valor = valor;
      _validade = _agora().add(validade);
      return valor;
    })()
        .whenComplete(() {
      if (identical(_consulta, consulta)) _consulta = null;
    });
    return _consulta = consulta;
  }

  void invalidar() {
    _geracao++;
    _chave = null;
    _valor = null;
    _validade = null;
    _consulta = null;
  }
}
