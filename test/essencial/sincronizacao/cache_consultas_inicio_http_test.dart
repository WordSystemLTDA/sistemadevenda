import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _BancoContado extends BancoLocal {
  final List<String> eventos;
  int consultas = 0;
  int leituras = 0;
  int gravacoes = 0;
  bool proibirLeitura = false;

  _BancoContado(super.db, this.eventos);

  @override
  Future<Map<String, Object?>?> consulta(String escopo, String chave) async {
    consultas++;
    eventos.add('consulta-local');
    if (proibirLeitura) {
      throw StateError('Nao ler SQLite antes de iniciar HTTP');
    }
    return super.consulta(escopo, chave);
  }

  @override
  Future<String?> ler(String chave) async {
    leituras++;
    eventos.add('documento-local');
    if (proibirLeitura) {
      throw StateError('Nao decodificar catalogo antes do HTTP');
    }
    return super.ler(chave);
  }

  @override
  Future<void> guardarConsulta(
      String escopo, String chave, Object? valor) async {
    gravacoes++;
    eventos.add('gravar-consulta');
    return super.guardarConsulta(escopo, chave, valor);
  }

  void zerarContagem() {
    consultas = 0;
    leituras = 0;
    gravacoes = 0;
    eventos.clear();
  }
}

class _HttpCatalogo implements HttpClientAdapter {
  final List<String> eventos;
  Object resposta = const [];
  bool offline = false;
  int chamadas = 0;
  Completer<void>? liberar;

  _HttpCatalogo(this.eventos);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas++;
    eventos.add('http');
    await liberar?.future;
    if (offline) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode(resposta), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const servidor = 'http://cozinha/api37/';
  const escopo = 'empresa32:usuario1';
  const parametros = {'empresa': '32', 'categoria': '0', 'pagina': '1'};
  late _BancoContado banco;
  late _HttpCatalogo http;
  late Dio dio;
  late CacheConsultas cache;
  late List<String> eventos;

  setUp(() async {
    eventos = [];
    final base = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    banco = _BancoContado(base.db, eventos);
    http = _HttpCatalogo(eventos);
    dio = Dio(BaseOptions(baseUrl: servidor))..httpClientAdapter = http;
    cache = CacheConsultas(dio, banco)
      ..servidor = servidor
      ..empresa = '32'
      ..escopo = escopo;
    dio.interceptors.add(cache);
  });

  tearDown(() async {
    dio.close(force: true);
    await banco.db.close();
  });

  String chave(String rota) => CacheConsultas.chave(RequestOptions(
      path: rota, baseUrl: servidor, queryParameters: parametros));

  for (final rota in [
    'produtos/listar.php',
    'produtos/listar_por_categoria.php',
    'produtos/listar_por_id.php',
    'categorias/listar.php',
  ]) {
    test('$rota inicia HTTP sem ler SQLite ou decodificar catalogo salvo',
        () async {
      await banco.guardarConsulta(escopo, chave(rota), [
        {'id': '1', 'nome': 'Antigo'},
      ]);
      await banco.gravar(
          'catalogo:$escopo',
          jsonEncode({
            'produtos': [
              {'id': '1', 'nome': 'Antigo'},
            ],
          }));
      banco.zerarContagem();
      banco.proibirLeitura = true;
      http.resposta = [
        {'id': '1', 'nome': 'Atualizado'},
        {'id': '2', 'nome': 'Novo produto'},
      ];

      final resposta = await dio.get(rota, queryParameters: parametros);

      expect(http.chamadas, 1);
      expect(eventos, ['http', 'gravar-consulta']);
      expect(banco.consultas, 0);
      expect(banco.leituras, 0);
      expect(banco.gravacoes, 1);
      expect(resposta.data, http.resposta);
      expect(resposta.extra['cacheLocal'], isNot(true));
      // Verifica o retrato com consulta direta, sem alterar os contadores.
      final salvo = await banco.db.query('consultas',
          where: 'escopo = ? AND chave = ?', whereArgs: [escopo, chave(rota)]);
      expect(jsonDecode(salvo.single['valor'] as String), http.resposta);
    });
  }

  test('duas consultas online trazem inclusao nova sem leitura local',
      () async {
    const rota = 'produtos/listar_por_categoria.php';
    banco.proibirLeitura = true;
    http.resposta = [
      {'id': '1', 'nome': 'Primeiro'},
    ];
    expect(
        (await dio.get(rota, queryParameters: parametros)).data, hasLength(1));
    http.resposta = [
      {'id': '1', 'nome': 'Primeiro'},
      {'id': '2', 'nome': 'Cadastrado agora'},
    ];
    expect(
        (await dio.get(rota, queryParameters: parametros)).data, hasLength(2));
    expect(http.chamadas, 2);
    expect(banco.consultas, 0);
    expect(banco.leituras, 0);
    expect(banco.gravacoes, 2);
  });

  test('abertura usa catalogo local e atualiza categorias em segundo plano',
      () async {
    const rota = 'categorias/listar.php';
    final local = [
      {'id': '0', 'nome': 'Todos local'},
    ];
    final atualizado = [
      {'id': '0', 'nome': 'Todos atualizado'},
    ];
    await banco.gravar(
        'catalogo:$escopo', jsonEncode({'categorias': local, 'produtos': []}));
    banco.zerarContagem();
    http.resposta = atualizado;
    http.liberar = Completer<void>();
    final concluiuAtualizacao = Completer<void>();
    cache.aoAtualizar = () {
      if (!concluiuAtualizacao.isCompleted) concluiuAtualizacao.complete();
    };

    final resposta = await dio.get(rota,
        queryParameters: const {'empresa': '32'},
        options: Options(extra: {'cachePrimeiro': true}));

    expect(resposta.data, local);
    expect(resposta.extra['cacheLocal'], isTrue);
    expect(resposta.extra['atualizandoEmSegundoPlano'], isTrue);
    for (var i = 0; i < 20 && http.chamadas == 0; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(http.chamadas, 1);
    expect(concluiuAtualizacao.isCompleted, isFalse);

    http.liberar!.complete();
    await concluiuAtualizacao.future;
    final salvo = await banco.consulta(
        escopo, CacheConsultas.chave(resposta.requestOptions));
    expect(jsonDecode(salvo!['valor'] as String), atualizado);
  });

  test('primeira falha consulta retrato so depois de tentar HTTP', () async {
    const rota = 'produtos/listar_por_categoria.php';
    final salvo = [
      {'id': '1', 'nome': 'Disponivel offline'},
    ];
    await banco.guardarConsulta(escopo, chave(rota), salvo);
    banco.zerarContagem();
    http.offline = true;

    final resposta = await dio.get(rota, queryParameters: parametros);

    expect(eventos, ['http', 'consulta-local']);
    expect(resposta.data, salvo);
    expect(resposta.extra['cacheLocal'], isTrue);
    expect(cache.servidorDisponivel, isFalse);
    expect(banco.consultas, 1);
    expect(banco.leituras, 0);
    expect(banco.gravacoes, 0);

    // Offline recente usa o retrato sem esperar outro timeout da rede.
    final novamente = await dio.get(rota, queryParameters: parametros);
    expect(novamente.data, salvo);
    expect(novamente.extra['cacheLocal'], isTrue);
    expect(http.chamadas, 1);
  });

  test('falha sem consulta exata deriva produtos do catalogo offline',
      () async {
    const rota = 'produtos/listar_por_categoria.php';
    final itens = [
      {'id': '1', 'nome': 'Arroz', 'categoria': '7'},
      {'id': '2', 'nome': 'Feijao', 'categoria': '7'},
    ];
    await banco.gravar('catalogo:$escopo', jsonEncode({'produtos': itens}));
    banco.zerarContagem();
    http.offline = true;

    final resposta = await dio.get(rota, queryParameters: parametros);

    expect(eventos, ['http', 'consulta-local', 'documento-local']);
    expect(resposta.extra['cacheLocal'], isTrue);
    expect(resposta.data, itens);
    expect(banco.consultas, 1);
    expect(banco.leituras, 1);
    expect(banco.gravacoes, 0);
  });

  test('reconexao volta ao HTTP antes de ler o retrato local', () async {
    const rota = 'categorias/listar.php';
    await banco.guardarConsulta(escopo, chave(rota), [
      {'id': '1', 'nome': 'Categoria antiga'},
    ]);
    http.offline = true;
    final offline = await dio.get(rota, queryParameters: parametros);
    expect(offline.extra['cacheLocal'], isTrue);
    cache.confirmarConexao();
    banco.zerarContagem();
    banco.proibirLeitura = true;
    http.offline = false;
    http.resposta = [
      {'id': '2', 'nome': 'Categoria nova'},
    ];
    final online = await dio.get(rota, queryParameters: parametros);
    expect(online.data, http.resposta);
    expect(online.extra['cacheLocal'], isNot(true));
    expect(eventos, ['http', 'gravar-consulta']);
    expect(banco.consultas, 0);
    expect(banco.leituras, 0);
  });
}
