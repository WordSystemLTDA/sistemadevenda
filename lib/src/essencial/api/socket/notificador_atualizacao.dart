import 'dart:convert';
import 'dart:developer';

import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:flutter_modular/flutter_modular.dart';

class NotificadorAtualizacao {
  static void atendimento(String tipo) {
    final tipoNormalizado = _normalizarTipo(tipo);
    if (tipoNormalizado == null) return;

    try {
      AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: tipoNormalizado));

      final usuario = Modular.get<UsuarioProvedor>().usuario;
      Modular.get<Server>().write(jsonEncode({
        'tipo': tipoNormalizado,
        'nomeConexao': usuario?.nome ?? '',
      }));
    } catch (erro, stackTrace) {
      log('Falha ao notificar atualizacao de tela',
          error: erro, stackTrace: stackTrace);
    }
  }

  static String? _normalizarTipo(String tipo) {
    final texto = tipo.trim().toLowerCase();
    return switch (texto) {
      'mesa' => 'Mesa',
      'comanda' => 'Comanda',
      'balcao' || 'balcão' => 'Balcão',
      'delivery' => 'Delivery',
      _ => null,
    };
  }
}
