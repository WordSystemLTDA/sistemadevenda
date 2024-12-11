import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class Nfc {
  static Future<bool> enviarComando({
    TipoCardapio tipo = TipoCardapio.comanda,
    String id = '',
    String idComandaPedido = '',
    String nome = '',
    String codigo = '',
    bool ocupado = false,
  }) async {
    var server = Modular.get<Server>();
    var usuario = Modular.get<UsuarioProvedor>();

    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    if (server.connected == false) {
      var sucessoConexao = await server.start(conexao!.servidor, conexao.porta);

      if (sucessoConexao == false) {
        return false;
      }
    }

    // pedido
    if (tipo == TipoCardapio.mesa) {
      server.write(jsonEncode({
        'tipo': 'MesaNFC',
        'nomeConexao': usuario.usuario!.nome,
        'idUsuario': usuario.usuario!.id,
        'id': id,
        'idComandaPedido': idComandaPedido,
        'nome': nome,
        'codigo': codigo,
        'ocupado': ocupado,
      }));
    } else if (tipo == TipoCardapio.comanda) {
      server.write(jsonEncode({
        'tipo': 'ComandaNFC',
        'nomeConexao': usuario.usuario!.nome,
        'idUsuario': usuario.usuario!.id,
        'id': id,
        'idComandaPedido': idComandaPedido,
        'nome': nome,
        'codigo': codigo,
        'ocupado': ocupado,
      }));
    }

    return true;
  }
}
