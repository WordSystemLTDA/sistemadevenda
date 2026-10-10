import 'dart:convert';
import 'dart:developer';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ServicoConfigBigchef {
  final DioCliente dio;
  final UsuarioProvedor usuarioProvedor;
  ServicoConfigBigchef(this.dio, this.usuarioProvedor);

  static const caminhoAPI = 'config_bigchef';
  static final Map<String, ModeloConfigBigchef> _cachePorDestino = {};

  /// Le somente a copia local, inclusive antes de o sincronizador iniciar.
  Future<ModeloConfigBigchef?> listarSalva() async {
    final conta = usuarioProvedor.usuario;
    final empresa = conta?.empresa;
    if (conta == null || empresa == null || empresa.isEmpty) return null;
    final servidor = await dio.obterServidor();
    final config = await _lerSalva(servidor, empresa, conta.id ?? '');
    return _aplicar(config, conta, servidor);
  }

  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async {
    final conta = usuarioProvedor.usuario;
    final idEmpresa = conta?.empresa;
    if (conta == null || idEmpresa == null || idEmpresa.isEmpty) return null;
    final servidor = await dio.obterServidor();
    final chaveCache = BancoLocal.escopo(servidor, idEmpresa, conta.id ?? '');

    try {
      final response = await dio.cliente.get('$caminhoAPI/listar.php',
          queryParameters: {
            'empresa': idEmpresa,
            if (forcarAtualizacao)
              '_atualizacao': DateTime.now().microsecondsSinceEpoch,
          },
          options: Options(extra: {
            'semCache': forcarAtualizacao,
            'servidorFixo': servidor,
          }));
      final jsonData = response.data;
      if (jsonData is! Map) {
        final configCache =
            await _lerSalva(servidor, idEmpresa, conta.id ?? '');
        return await _aplicar(configCache, conta, servidor);
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
      // A consulta forcada tambem precisa sobreviver ao encerramento do app.
      try {
        if (response.extra['cacheLocal'] != true) {
          await (dio.cache?.banco ?? BancoLocal.instancia)?.guardarConsulta(
              chaveCache, CacheConsultas.chave(response.requestOptions), dados);
        }
      } catch (erro, stack) {
        log('Falha ao salvar configuracao local',
            error: erro, stackTrace: stack);
      }
      return await _aplicar(config, conta, servidor);
    } on DioException catch (e) {
      if (e.response == null) {
        if (kDebugMode) {
          log('ERRO API', error: e.error);
        }
      }

      final configCache = await _lerSalva(servidor, idEmpresa, conta.id ?? '');
      return _aplicar(configCache, conta, servidor);
    }
  }

  Future<ModeloConfigBigchef?> _lerSalva(
      String servidor, String empresa, String usuario) async {
    final escopo = BancoLocal.escopo(servidor, empresa, usuario);
    final memoria = _cachePorDestino[escopo];
    try {
      final requisicao = RequestOptions(
        path: '$caminhoAPI/listar.php',
        baseUrl: servidor,
        queryParameters: {'empresa': empresa},
      );
      final registro = await (dio.cache?.banco ?? BancoLocal.instancia)
          ?.consulta(escopo, CacheConsultas.chave(requisicao));
      if (registro == null) return memoria;
      final dados = jsonDecode(registro['valor'] as String);
      if (dados is! Map) return memoria;
      return ModeloConfigBigchef.fromMap(Map<String, dynamic>.from(dados));
    } catch (erro, stack) {
      log('Falha ao ler configuracao local', error: erro, stackTrace: stack);
      return memoria;
    }
  }

  Future<ModeloConfigBigchef?> _aplicar(
      ModeloConfigBigchef? config, UsuarioModelo conta, String servidor) async {
    if (config == null ||
        await dio.obterServidor() != servidor ||
        !identical(usuarioProvedor.usuario, conta)) {
      return null;
    }
    usuarioProvedor.setConfigBigChef(config);
    return config;
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

  bool _possuiCodigoSaboresPizza(Map<String, dynamic> dados) =>
      dados.containsKey('imprimircodigoprodutopreparo') ||
      dados.containsKey('imprimir_codigo_produto_preparo');

  bool _precisaCompletarComDesktop(Map<String, dynamic> dados) =>
      !(dados.containsKey('aumentarfontenumeropedidoentregador') ||
          dados.containsKey('aumentar_fonte_numero_pedido_entregador')) ||
      !(dados.containsKey('aumentarfontetotaisentregador') ||
          dados.containsKey('aumentar_fonte_totais_entregador')) ||
      !(dados.containsKey('aumentarfontepagamentoentregador') ||
          dados.containsKey('aumentar_fonte_pagamento_entregador')) ||
      !_possuiValorEmbalagemSeparada(dados) ||
      !_possuiConfiguracaoRecorrentes(dados) ||
      !_possuiFiltroProdutosPersonalizados(dados) ||
      !_possuiCodigoSaboresPizza(dados);

  String? _baseDesktop(String baseGarcom) {
    if (baseGarcom.isEmpty) return null;
    final normalizada = baseGarcom.endsWith('/') ? baseGarcom : '$baseGarcom/';
    final desktop = normalizada.replaceFirst(
      RegExp(r'/api_restaurantes_venda/api(?:1|6|37|38|39)/'),
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
