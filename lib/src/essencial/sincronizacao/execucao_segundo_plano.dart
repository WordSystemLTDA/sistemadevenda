import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class ExecucaoSegundoPlano {
  static const canal = MethodChannel('bigchef/sincronizacao');

  static Future<T> executar<T>(Future<T> Function() operacao) async {
    int? tarefa;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        tarefa = await canal.invokeMethod<int>('iniciarEnvio');
      } on MissingPluginException {
        // Testes e versoes anteriores do host continuam usando a fila duravel.
      } on PlatformException {
        // O sistema pode negar tempo adicional; isso nao descarta o pedido.
      }
    }
    try {
      return await operacao();
    } finally {
      if (tarefa != null) {
        try {
          await canal.invokeMethod<void>('concluirEnvio', tarefa);
        } on PlatformException {
          // O handler nativo de expiracao tambem encerra a tarefa.
        } on MissingPluginException {
          // O engine pode estar sendo encerrado.
        }
      }
    }
  }
}
