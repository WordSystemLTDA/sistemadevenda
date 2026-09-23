import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:app/src/essencial/utils/normalizar_busca.dart';
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
  int _geracaoAtendimento = 0;
  void Function()? aoAtualizar;

  CacheConsultas(this.cliente, this.banco);

  static const _rotaClientes = 'comandas/listar_clientes.php';

  static bool _atendimento(String rota) =>
      rota != _rotaClientes &&
      (rota.startsWith('mesas/') ||
          rota.startsWith('comandas/') ||
          rota.startsWith('cardapio/') ||
          rota.startsWith('itens_recorrentes/'));

  Future<void> invalidarAtendimentos() async {
    _geracaoAtendimento++;
    final linhas = await banco.db.query('consultas',
        columns: ['chave'], where: 'escopo = ?', whereArgs: [escopo]);
    await banco.db.transaction((tx) async {
      for (final linha in linhas) {
        final chaveConsulta = linha['chave'] as String;
        if (_atendimento((jsonDecode(chaveConsulta) as List).first as String)) {
          await tx.delete('consultas',
              where: 'escopo = ? AND chave = ?',
              whereArgs: [escopo, chaveConsulta]);
        }
      }
    });
  }

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
        SplayTreeMap<String, String>.from(opcoes.uri.queryParameters)
          ..remove('_consulta_atual')
          ..remove('_atualizacao'),
      ]);

  // Catalogo e formas de pagamento precisam refletir o cadastro atual a cada
  // leitura. O retrato persistido fica reservado para uma falha de conexao.
  static bool _exigeConsultaAtual(String rota) =>
      _atendimento(rota) ||
      rota == _rotaClientes ||
      rota.startsWith('balcao/') ||
      rota.startsWith('delivery/') ||
      rota.startsWith('recorrentes/') ||
      rota.startsWith('enderecos_clientes/') ||
      rota.startsWith('permissoes_bigchef/') ||
      rota.startsWith('produtos/') ||
      rota.startsWith('categorias/') ||
      rota.startsWith('tela_nfe_saida/');

  bool _permitido(RequestOptions opcoes) {
    if (escopo.isEmpty ||
        (opcoes.method != 'GET' && caminho(opcoes) != 'balcao/listar.php') ||
        opcoes.extra['semCache'] == true ||
        opcoes.baseUrl != servidor) {
      return false;
    }
    final parametros = opcoes.uri.queryParameters;
    final empresaConsulta = parametros['empresa'] ?? parametros['id_empresa'];
    if (empresaConsulta != null && empresaConsulta != empresa) {
      return false;
    }
    final rota = caminho(opcoes);
    if ([
      'tela_nfe_saida/listar_banco_pix.php',
      'tela_nfe_saida/listar_datas_vendas.php',
      'tela_nfe_saida/listar_bancos.php',
      'balcao/listar.php',
      'delivery/listar_opcoes.php',
      'permissoes_bigchef/listar_permissoes_bigchef.php',
      'enderecos_clientes/listar_por_cliente.php',
      'recorrentes/listar.php',
    ].contains(rota)) {
      return true;
    }
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
    options.extra['geracaoAtendimento'] = _geracaoAtendimento;
    final falhouRecentemente = _ultimaFalha != null &&
        DateTime.now().difference(_ultimaFalha!) < const Duration(seconds: 5);
    options.connectTimeout = const Duration(seconds: 3);
    options.receiveTimeout = const Duration(seconds: 8);
    // Online o retrato nao sera usado: nao ler SQLite nem decodificar todo o
    // catalogo antes de iniciar o HTTP. A falha continua usando onError abaixo.
    if (!falhouRecentemente && _exigeConsultaAtual(caminho(options))) {
      return handler.next(options);
    }
    try {
      final consulta = await banco.consulta(alvo, chave(options));
      Object? dados =
          consulta == null ? null : jsonDecode(consulta['valor'] as String);
      dados ??= await _derivar(options, alvo);
      if (dados != null &&
          (falhouRecentemente || !_exigeConsultaAtual(caminho(options)))) {
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
      if (falhouRecentemente) {
        return handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            message: 'Estes dados ainda nao estao salvos no aparelho.'));
      }
    } catch (erro) {
      return handler.reject(DioException(requestOptions: options, error: erro));
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    final alvo = response.requestOptions.extra['escopoCache'] as String?;
    if (alvo != null &&
        alvo == escopo &&
        (!_atendimento(caminho(response.requestOptions)) ||
            (response.requestOptions.extra['geracaoAtendimento'] ??
                    _geracaoAtendimento) ==
                _geracaoAtendimento) &&
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
        final pesquisa = normalizarBusca(q['pesquisa'] ?? '');
        final exato = q['codigo_exato'] == 'Sim';
        itens = itens
            .where((p) => exato
                ? _codigo(p['codigo'].toString()) == _codigo(pesquisa)
                : ['nome', 'codigo', 'valorVenda'].any((campo) =>
                    normalizarBusca(p[campo].toString()).contains(pesquisa)))
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
      if (rota == _rotaClientes && dados is List) {
        final texto = termo.trim();
        final numeros = texto.replaceAll(RegExp(r'\D'), '');
        // Mesmo contrato da busca de clientes da API: nome/razao, ID e
        // celular com ou sem mascara. Nao ampliar a busca de atendimentos.
        return dados.whereType<Map>().where((cliente) {
          final correspondeTexto = [
            'id',
            'nome',
            'nome_puro',
            'razao_social',
            'celular'
          ].any((campo) =>
              (cliente[campo] ?? '').toString().toLowerCase().contains(texto));
          final celular = (cliente['celular'] ?? '')
              .toString()
              .replaceAll(RegExp(r'\D'), '');
          return correspondeTexto ||
              (numeros.isNotEmpty && celular.contains(numeros));
        }).toList();
      }
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
