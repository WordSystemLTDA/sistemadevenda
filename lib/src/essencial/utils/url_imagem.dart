import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:flutter_modular/flutter_modular.dart';

class UrlImagem {
  static String? _baseHostCache;

  static Future<String> obterBaseHostImagens() async {
    if (_baseHostCache != null && _baseHostCache!.isNotEmpty) {
      return _baseHostCache!;
    }

    final servidorSocket = Modular.get<Server>();
    final hostSocket = _normalizarHost(servidorSocket.hostname);

    if (servidorSocket.connected && hostSocket.isNotEmpty) {
      _baseHostCache = 'http://$hostSocket';
      return _baseHostCache!;
    }

    final conexao = await ConfigSharedPreferences().getConexao();

    if (conexao?.tipoConexao == 'online') {
      _baseHostCache = 'https://bigchef.com.br';
      return _baseHostCache!;
    }

    final hostConfigurado = _normalizarHost(conexao?.servidor ?? '');
    if (hostConfigurado.isNotEmpty) {
      _baseHostCache = 'http://$hostConfigurado';
      return _baseHostCache!;
    }

    _baseHostCache = 'https://bigchef.com.br';
    return _baseHostCache!;
  }

  static String montarUrlImagem({
    required String foto,
    required String baseHost,
  }) {
    return '$baseHost/sistema/apis_restaurantes/imagens/$foto';
  }

  static String _normalizarHost(String valor) {
    var host = valor.trim();

    if (host.isEmpty) {
      return '';
    }

    if (host.startsWith('http://')) {
      host = host.substring(7);
    } else if (host.startsWith('https://')) {
      host = host.substring(8);
    }

    final barra = host.indexOf('/');
    if (barra != -1) {
      host = host.substring(0, barra);
    }

    return host.trim();
  }
}
