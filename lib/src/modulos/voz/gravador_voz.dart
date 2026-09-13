import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'pedido_falado.dart';

class GravadorVoz {
  final AudioRecorder _gravador = AudioRecorder();
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
    final permitido = await _gravador.hasPermission();
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
    await _gravador.start(
        const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 64000,
            sampleRate: 24000,
            numChannels: 1),
        path: '${_pasta!.path}/pedido.m4a');
  }

  Future<String> concluir() async {
    final caminho = await _gravador.stop();
    if (caminho == null ||
        !await File(caminho).exists() ||
        await File(caminho).length() > 1024 * 1024) {
      throw const FalhaPedidoVoz(
          'Não foi possível concluir a gravação. Grave novamente.');
    }
    return caminho;
  }

  Future<void> cancelar() {
    ++_operacao;
    return _gravador.cancel();
  }

  Future<void> dispose() async {
    _encerrado = true;
    ++_operacao;
    try {
      await _gravador.dispose();
    } finally {
      final pasta = _pasta;
      if (pasta != null && await pasta.exists()) {
        await pasta.delete(recursive: true);
      }
    }
  }
}
