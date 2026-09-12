import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import 'banco_local.dart';

class CacheConsultas extends Interceptor {
  final Dio cliente;
  final BancoLocal banco;
  String escopo = '';
  String servidor = '';
  String empresa = '';
  bool servidorDisponivel = true;
  DateTime? _ultimaFalha;
  final Set<String> _atualizando = {};
  void Function()? aoAtualizar;

  CacheConsultas(this.cliente, this.banco);

  void confirmarConexao() {
    servidorDisponivel = true;
    _ultimaFalha = null;
  }

  static bool falhaDeConexao(DioException erro) =>
      erro.type == DioExceptionType.connectionError ||
      erro.type == DioExceptionType.connectionTimeout ||
      erro.type == DioExceptionType.receiveTimeout ||
      erro.type == DioExceptionType.sendTimeout ||
      erro.error is SocketException;

  static String caminho(RequestOptions opcoes) =>
      Uri.parse(opcoes.path).path.replaceFirst(RegExp(r'^/+'), '');

  static String chave(RequestOptions opcoes) => jsonEncode([
        caminho(opcoes),
        SplayTreeMap<String, String>.from(opcoes.uri.queryParameters),
      ]);

  bool _permitido(RequestOptions opcoes) {
    if (escopo.isEmpty ||
        opcoes.method != 'GET' ||
        opcoes.extra['semCache'] == true ||
        opcoes.baseUrl != servidor) {
      return false;
    }
    final parametros = opcoes.uri.queryParameters;
    if (parametros['empresa'] != null && parametros['empresa'] != empresa) {
      return false;
    }
    final rota = caminho(opcoes);
    if (rota == 'cardapio/listar_por_id.php') {
      return ['Mesa', 'Comanda'].contains(parametros['tipo']) &&
          parametros['imprimir'] != 'true';
    }
    return RegExp(r'^(produtos|categorias|mesas|comandas|cardapio|'
            r'itens_recorrentes|config|config_bigchef)/listar[^/]*\.php$')
        .hasMatch(rota);
  }

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    if (!_permitido(options)) return handler.next(options);
    final alvo = escopo;
    options.extra['escopoCache'] = alvo;
    try {
      final consulta = await banco.consulta(alvo, chave(options));
      Object? dados =
          consulta == null ? null : jsonDecode(consulta['valor'] as String);
      dados ??= await _derivar(options, alvo);
      if (dados != null) {
        final recente = consulta != null &&
            DateTime.now().millisecondsSinceEpoch -
                    (consulta['atualizado'] as int) <
                10000;
        if (!recente) _atualizar(options, alvo);
        return handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: dados,
            extra: {'cacheLocal': true}));
      }
      if (_ultimaFalha != null &&
          DateTime.now().difference(_ultimaFalha!) <
              const Duration(seconds: 5)) {
        return handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'Estes dados ainda nao estao salvos no aparelho.'));
      }
    } catch (erro) {
      return handler.reject(DioException(requestOptions: options, error: erro));
    }
    options.connectTimeout = const Duration(seconds: 3);
    options.receiveTimeout = const Duration(seconds: 8);
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final alvo = response.requestOptions.extra['escopoCache'] as String?;
    if (alvo != null &&
        alvo == escopo &&
        response.extra['cacheLocal'] != true &&
        response.statusCode == 200 &&
        (response.data is List || response.data is Map) &&
        !(response.data is Map && response.data['sucesso'] == false)) {
      try {
        await banco.guardarConsulta(
            alvo, chave(response.requestOptions), response.data);
        if (caminho(response.requestOptions) == 'cardapio/listar_por_id.php' &&
            response.data is Map &&
            response.data['id'] != null &&
            response.data['versao_atendimento'] != null) {
          await banco.gravar('versao:$alvo:${response.data['id']}',
              response.data['versao_atendimento'].toString());
        }
        confirmarConexao();
      } catch (_) {
        // Uma consulta online ainda pode ser exibida se o cache nao couber.
      }
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (falhaDeConexao(err)) {
      servidorDisponivel = false;
      _ultimaFalha = DateTime.now();
      final alvo = err.requestOptions.extra['escopoCache'] as String?;
      if (alvo != null && alvo == escopo) {
        try {
          final consulta =
              await banco.consulta(alvo, chave(err.requestOptions));
          final dados = consulta == null
              ? await _derivar(err.requestOptions, alvo)
              : jsonDecode(consulta['valor'] as String);
          if (dados != null) {
            return handler.resolve(Response(
                requestOptions: err.requestOptions,
                data: dados,
                statusCode: 200,
                extra: {'cacheLocal': true}));
          }
        } catch (_) {}
      }
    }
    handler.next(err);
  }

  void _atualizar(RequestOptions opcoes, String alvo) {
    final identificador = '$alvo:${chave(opcoes)}';
    if (!_atualizando.add(identificador)) return;
    if (_ultimaFalha != null &&
        DateTime.now().difference(_ultimaFalha!) < const Duration(seconds: 5)) {
      _atualizando.remove(identificador);
      return;
    }
    unawaited(() async {
      try {
        await cliente.fetch(opcoes.copyWith(
          connectTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 8),
          extra: {
            ...opcoes.extra,
            'semCache': true,
            'servidorFixo': opcoes.baseUrl
          },
        ));
        if (alvo == escopo) aoAtualizar?.call();
      } catch (_) {
        // O ultimo retrato valido continua disponivel durante a reconexao.
      } finally {
        _atualizando.remove(identificador);
      }
    }());
  }

  Future<Object?> _derivar(RequestOptions opcoes, String alvo) async {
    final rota = caminho(opcoes);
    final q = opcoes.uri.queryParameters;
    if (rota.startsWith('produtos/')) {
      final salvo = await banco.ler('catalogo:$alvo');
      if (salvo == null) return null;
      final catalogo = jsonDecode(salvo) as Map<String, dynamic>;
      if (rota == 'produtos/listar_por_id.php') {
        final tamanho = q['id_tamanhos_pizza'] ?? '';
        return (catalogo['detalhes'] as Map?)?['${q['id']}:$tamanho'];
      }
      if (rota != 'produtos/listar.php' &&
          rota != 'produtos/listar_por_categoria.php') {
        return null;
      }
      var itens = List<Map<String, dynamic>>.from(catalogo['produtos'] as List);
      final categoria = q['categoria'] ?? '0';
      if (categoria != '0' && categoria.isNotEmpty) {
        final idsPromocao =
            (catalogo['categoriasEspeciais'] as Map?)?[categoria] as List?;
        itens = itens
            .where((p) => idsPromocao != null
                ? idsPromocao.contains(p['id'])
                : p['categoria'] == categoria)
            .toList();
      }
      if (rota == 'produtos/listar.php') {
        final pesquisa = (q['pesquisa'] ?? '').trim().toLowerCase();
        final exato = q['codigo_exato'] == 'Sim';
        itens = itens
            .where((p) => exato
                ? _codigo(p['codigo'].toString()) == _codigo(pesquisa)
                : ['nome', 'codigo', 'valorVenda'].any((campo) =>
                    p[campo].toString().toLowerCase().contains(pesquisa)))
            .toList();
        itens.sort(
            (a, b) => a['nome'].toString().compareTo(b['nome'].toString()));
        return itens;
      }
      final pagina = int.tryParse(q['pagina'] ?? '1') ?? 1;
      return itens.skip((pagina - 1).clamp(0, 1000000) * 15).take(15).toList();
    }
    if (q['pesquisa']?.isNotEmpty == true) {
      final semBusca =
          opcoes.copyWith(path: rota, queryParameters: {...q, 'pesquisa': ''});
      final base = await banco.consulta(alvo, chave(semBusca));
      if (base == null) return null;
      final dados = jsonDecode(base['valor'] as String);
      final termo = q['pesquisa']!.toLowerCase();
      bool corresponde(Map item) =>
          ['nome', 'codigo', 'nomeCliente', 'obs'].any((key) =>
              (item[key] ?? '').toString().toLowerCase().contains(termo));
      if (dados is List) {
        final campo = rota.startsWith('mesas/') ? 'mesas' : 'comandas';
        return dados
            .whereType<Map>()
            .map((e) => e[campo] is List
                ? {
                    ...e,
                    campo: (e[campo] as List)
                        .whereType<Map>()
                        .where(corresponde)
                        .toList()
                  }
                : e)
            .where((e) => e[campo] is List || corresponde(e))
            .toList();
      }
    }
    return null;
  }

  static String _codigo(String valor) {
    final codigo = valor.trim().toLowerCase();
    if (!RegExp(r'^\d+$').hasMatch(codigo)) return codigo;
    final numero = codigo.replaceFirst(RegExp(r'^0+'), '');
    return numero.isEmpty ? '0' : numero;
  }
}
