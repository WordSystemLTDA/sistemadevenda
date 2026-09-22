import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'falha_pedido_voz.dart';

class GravadorVoz {
  AudioRecorder? _gravador;
  Directory? _pasta;
  int _operacao = 0;
  bool _encerrado = false;

  void _validar(int operacao) {
    if (_encerrado || operacao != _operacao) {
      throw const FalhaPedidoVoz('Gravação cancelada.');
    }
  }

  Future<void> iniciar() async {
    final operacao = ++_operacao;
    _validar(operacao);
    // O plugin inicia um Future no construtor. Aguarde-o no mesmo fluxo
    // para capturar MissingPluginException em builds anteriores ao microfone.
    final gravador = _gravador ??= AudioRecorder();
    final permitido = await gravador.hasPermission();
    _validar(operacao);
    if (!permitido) {
      throw const FalhaPedidoVoz(
          'Microfone sem permissão. Libere o acesso nos ajustes do celular.');
    }
    _pasta ??= await (await getTemporaryDirectory()).createTemp('pedido_voz_');
    if (_encerrado || operacao != _operacao) {
      final pasta = _pasta;
      _pasta = null;
      if (pasta != null && await pasta.exists()) {
        await pasta.delete(recursive: true);
      }
      _validar(operacao);
    }
    await gravador.start(
        const RecordConfig(
            encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
        path: '${_pasta!.path}/pedido.wav');
  }

  Future<String> concluir() async {
    final caminho = await _gravador?.stop();
    if (caminho == null ||
        !await File(caminho).exists() ||
        await File(caminho).length() <= 44 ||
        await File(caminho).length() > 3 * 1024 * 1024) {
      throw const FalhaPedidoVoz(
          'Não foi possível concluir a gravação. Grave novamente.');
    }
    return caminho;
  }

  Future<void> aguardarFimDaFala(
      {Duration limite = const Duration(seconds: 12),
      Future<void>? pararSolicitado}) async {
    final gravador = _gravador;
    if (gravador == null || _encerrado) {
      throw const FalhaPedidoVoz('O microfone nao esta gravando.');
    }

    final inicio = DateTime.now();
    DateTime? ultimaVoz;
    var ouviuVoz = false;
    final fim = Completer<void>();
    late final StreamSubscription<Amplitude> amplitude;
    amplitude =
        gravador.onAmplitudeChanged(const Duration(milliseconds: 180)).listen(
      (valor) {
        if (fim.isCompleted) return;
        final agora = DateTime.now();
        final decorrido = agora.difference(inicio);
        if (valor.current >= -42) {
          ouviuVoz = true;
          ultimaVoz = agora;
        }
        final silencio =
            ultimaVoz == null ? Duration.zero : agora.difference(ultimaVoz!);
        if ((ouviuVoz &&
                decorrido >= const Duration(milliseconds: 900) &&
                silencio >= const Duration(milliseconds: 1400)) ||
            (!ouviuVoz && decorrido >= const Duration(seconds: 5))) {
          fim.complete();
        }
      },
      onError: (_) {
        if (!fim.isCompleted) fim.complete();
      },
    );
    try {
      await Future.any([
        fim.future,
        Future<void>.delayed(limite),
        if (pararSolicitado != null) pararSolicitado,
      ]);
    } finally {
      await amplitude.cancel();
    }
  }

  Future<void> cancelar() async {
    ++_operacao;
    await _gravador?.cancel();
  }

  Future<void> dispose() async {
    _encerrado = true;
    ++_operacao;
    try {
      await _gravador?.dispose();
    } finally {
      final pasta = _pasta;
      if (pasta != null && await pasta.exists()) {
        await pasta.delete(recursive: true);
      }
    }
  }
}
