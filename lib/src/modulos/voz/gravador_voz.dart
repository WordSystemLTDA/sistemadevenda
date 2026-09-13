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
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 24000,
            numChannels: 1),
        path: '${_pasta!.path}/pedido.m4a');
  }

  Future<String> concluir() async {
    final caminho = await _gravador?.stop();
    if (caminho == null ||
        !await File(caminho).exists() ||
        await File(caminho).length() > 1024 * 1024) {
      throw const FalhaPedidoVoz(
          'Não foi possível concluir a gravação. Grave novamente.');
    }
    return caminho;
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
