import 'dart:developer';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoConfigBigchef {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoConfigBigchef(this.dio, this.usuarioProvedor);

  static const caminhoAPI = 'config_bigchef';
  static final Map<String, ModeloConfigBigchef> _cachePorDestino = {};

  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async {
    final idEmpresa = usuarioProvedor.usuario?.empresa;
    if (idEmpresa == null || idEmpresa.isEmpty) return null;

    try {
      final response = await dio.cliente.get('$caminhoAPI/listar.php',
          queryParameters: {
            'empresa': idEmpresa,
            if (forcarAtualizacao)
              '_atualizacao': DateTime.now().microsecondsSinceEpoch,
          },
          options: Options(extra: {'semCache': forcarAtualizacao}));
      final jsonData = response.data;
      final chaveCache = _chaveCache(response.requestOptions, idEmpresa);
      if (jsonData is! Map) {
        final configCache = _cachePorDestino[chaveCache];
        if (configCache != null) usuarioProvedor.setConfigBigChef(configCache);
        return configCache;
      }

      final dados = Map<String, dynamic>.from(jsonData);
      if (_precisaCompletarComDesktop(dados)) {
        final dadosDesktop = await _listarConfiguracaoDesktop(
          response.requestOptions.baseUrl,
          idEmpresa,
        );
        if (dadosDesktop != null) {
          for (final entrada in dadosDesktop.entries) {
            dados.putIfAbsent(entrada.key, () => entrada.value);
          }
        }
      }

      final config = ModeloConfigBigchef.fromMap(dados);
      _cachePorDestino[chaveCache] = config;
      usuarioProvedor.setConfigBigChef(config);
      return config;
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      final configCache =
          _cachePorDestino[_chaveCache(e.requestOptions, idEmpresa)];
      if (configCache != null) usuarioProvedor.setConfigBigChef(configCache);
      return configCache;
    }
  }

  bool _possuiValorEmbalagemSeparada(Map<String, dynamic> dados) =>
      dados.containsKey('valorembalagemseparada') ||
      dados.containsKey('valor_embalagem_separada');

  bool _possuiConfiguracaoRecorrentes(Map<String, dynamic> dados) =>
      dados.containsKey('clientecompedidosdecorrentes') ||
      dados.containsKey('cliente_com_pedidos_decorrentes');

  bool _possuiFiltroProdutosPersonalizados(Map<String, dynamic> dados) =>
      dados.containsKey('mostrarapenasprodutosativovenda') ||
      dados.containsKey('mostrar_apenas_produtos_ativo_venda');

  bool _precisaCompletarComDesktop(Map<String, dynamic> dados) =>
      !_possuiValorEmbalagemSeparada(dados) ||
      !_possuiConfiguracaoRecorrentes(dados) ||
      !_possuiFiltroProdutosPersonalizados(dados);

  String _chaveCache(RequestOptions requisicao, String empresa) {
    final base = requisicao.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return '$base|$empresa';
  }

  String? _baseDesktop(String baseGarcom) {
    if (baseGarcom.isEmpty) return null;
    final normalizada = baseGarcom.endsWith('/') ? baseGarcom : '$baseGarcom/';
    final desktop = normalizada.replaceFirst(
      RegExp(r'/api_restaurantes_venda/api(?:1|6|37)/'),
      '/api_desktop/1.0.01/',
    );
    return desktop == normalizada ? null : desktop;
  }

  Future<Map<String, dynamic>?> _listarConfiguracaoDesktop(
    String baseGarcom,
    String empresa,
  ) async {
    final baseDesktop = _baseDesktop(baseGarcom);
    if (baseDesktop == null) return null;

    try {
      final response = await dio.cliente.get(
        '$caminhoAPI/listar.php',
        queryParameters: {'empresa': empresa},
        options: Options(extra: {
          'semCache': true,
          'servidorFixo': baseDesktop,
        }),
      );
      final dados = response.data;
      if (dados is! Map) return null;
      return Map<String, dynamic>.from(dados);
    } on DioException {
      return null;
    }
  }
}
