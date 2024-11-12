import 'dart:convert';

import 'package:app/src/essencial/api/socket/client.dart';
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
    var cliente = Modular.get<Client>();
    var usuario = Modular.get<UsuarioProvedor>();

    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    if (cliente.connected == false) {
      var sucessoConexao = await cliente.connect(conexao!.servidor, int.parse(conexao.porta));

      if (sucessoConexao == false) {
        return false;
      }
    }

    // pedido
    if (tipo == TipoCardapio.mesa) {
      cliente.write(jsonEncode({
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
      cliente.write(jsonEncode({
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
