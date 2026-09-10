import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:flutter_modular/flutter_modular.dart';

class UrlImagem {
  static const String _caminhoBaseImagens =
      '/sistema/apis_restaurantes/imagens/';
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
    final caminhoImagem = _normalizarCaminhoImagem(foto);
    if (caminhoImagem.isEmpty) {
      return '';
    }

    if (_ehUrlAbsoluta(caminhoImagem)) {
      return caminhoImagem;
    }

    final host = baseHost.trim().replaceFirst(RegExp(r'/+$'), '');
    return '$host$_caminhoBaseImagens$caminhoImagem';
  }

  static String _normalizarCaminhoImagem(String valor) {
    final foto = valor.trim().replaceAll('\\', '/');
    if (foto.isEmpty) {
      return '';
    }

    final uri = Uri.tryParse(foto);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      final caminhoRelativo = _extrairCaminhoRelativoApi(uri.path);
      return caminhoRelativo ?? foto;
    }

    final caminhoRelativo = _extrairCaminhoRelativoApi(foto);
    if (caminhoRelativo != null) {
      return caminhoRelativo;
    }

    return foto.replaceFirst(RegExp(r'^/+'), '');
  }

  static String? _extrairCaminhoRelativoApi(String valor) {
    var caminho = valor.trim().replaceAll('\\', '/');
    if (caminho.isEmpty) {
      return null;
    }

    final indice = caminho.indexOf(_caminhoBaseImagens);
    if (indice != -1) {
      caminho = caminho.substring(indice + _caminhoBaseImagens.length);
      return caminho.replaceFirst(RegExp(r'^/+'), '');
    }

    caminho = caminho.replaceFirst(RegExp(r'^/+'), '');
    const caminhoSemBarra = 'sistema/apis_restaurantes/imagens/';
    if (caminho.startsWith(caminhoSemBarra)) {
      return caminho.substring(caminhoSemBarra.length);
    }

    const pastaImagens = 'imagens/';
    if (caminho.startsWith(pastaImagens)) {
      return caminho.substring(pastaImagens.length);
    }

    return null;
  }

  static bool _ehUrlAbsoluta(String valor) {
    final uri = Uri.tryParse(valor);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
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
