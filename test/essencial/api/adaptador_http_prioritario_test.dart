import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/adaptador_http_prioritario.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _ChamadaPendente {
  final RequestOptions options;
  final Future<void>? cancelFuture;
  final resposta = Completer<ResponseBody>();

  _ChamadaPendente(this.options, this.cancelFuture);

  void concluir(String dados) =>
      resposta.complete(ResponseBody.fromString(dados, 200));
}

class _TransporteControlado implements HttpClientAdapter {
  final chamadas = <_ChamadaPendente>[];
  int preparacoesAtivas = 0;
  int maxPreparacoes = 0;
  bool fechado = false;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    final chamada = _ChamadaPendente(options, cancelFuture);
    chamadas.add(chamada);
    final preparacao =
        options.method == 'GET' && options.extra['preparacaoOffline'] == true;
    if (preparacao) {
      preparacoesAtivas++;
      if (preparacoesAtivas > maxPreparacoes) {
        maxPreparacoes = preparacoesAtivas;
      }
    }
    try {
      return await chamada.resposta.future;
    } finally {
      if (preparacao) preparacoesAtivas--;
    }
  }

  @override
  void close({bool force = false}) => fechado = true;
}

RequestOptions _consulta(String path,
        {bool preparacao = true, String method = 'GET'}) =>
    RequestOptions(
      path: path,
      method: method,
      extra: {'preparacaoOffline': preparacao},
    );

Matcher get _cancelamento => isA<DioException>()
    .having((erro) => erro.type, 'type', DioExceptionType.cancel);

Future<void> _consumir(Future<ResponseBody> resposta) async {
  await (await resposta).stream.drain<void>();
}

Future<void> _aguardarChamadas(
    _TransporteControlado transporte, int total) async {
  final tempo = Stopwatch()..start();
  while (tempo.elapsed < const Duration(seconds: 3)) {
    if (transporte.chamadas.length >= total) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('Esperava $total chamadas; recebeu ${transporte.chamadas.length}.');
}

class _RelogioReal {
  const _RelogioReal();

  Future<void> pump([Duration duracao = Duration.zero]) =>
      Future<void>.delayed(duracao + const Duration(milliseconds: 5));
}

void main() {
  const respiro = Duration(milliseconds: 120);

  test('Dio descartando corpo de erro tambem libera a fila', () async {
    final transporte = _TransporteControlado();
    final dio = Dio()
      ..httpClientAdapter =
          AdaptadorHttpPrioritario(transporte, respiro: respiro);
    addTearDown(() => dio.close(force: true));
    final falha = dio.get('/erro',
        options: Options(
            extra: {'preparacaoOffline': true},
            receiveDataWhenStatusError: false));
    final expectativa = expectLater(falha, throwsA(isA<DioException>()));
    await _aguardarChamadas(transporte, 1);
    var fechou = false;
    transporte.chamadas.single.resposta.complete(
        ResponseBody.fromString('erro', 503, onClose: () => fechou = true));
    await expectativa;
    expect(fechou, isTrue);
    final seguinte = dio.get('/seguinte',
        options: Options(extra: {'preparacaoOffline': true}));
    await _aguardarChamadas(transporte, 2);
    transporte.chamadas.last.concluir('ok');
    expect((await seguinte).data, 'ok');
  });

  test(
      'Dio consome JSON lento e libera fila apos status de erro e cancelamento',
      () async {
    final transporte = _TransporteControlado();
    final adapter =
        AdaptadorHttpPrioritario(transporte, respiro: Duration.zero);
    final dio = Dio()..httpClientAdapter = adapter;
    addTearDown(() => dio.close(force: true));
    final offline = Options(extra: {'preparacaoOffline': true});
    final corpo = StreamController<Uint8List>();
    final primeira = dio.get<dynamic>('/primeira', options: offline);
    final segunda = dio.get<dynamic>('/falha', options: offline);
    final falha = expectLater(
        segunda,
        throwsA(isA<DioException>()
            .having((e) => e.type, 'type', DioExceptionType.badResponse)
            .having((e) => e.response?.data, 'data', {'erro': 'teste'})));
    await _aguardarChamadas(transporte, 1);
    transporte.chamadas[0].resposta
        .complete(ResponseBody(corpo.stream, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    }));
    corpo.add(Uint8List.fromList(utf8.encode('{"preco":')));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(transporte.chamadas, hasLength(1));
    corpo.add(Uint8List.fromList(utf8.encode('45}')));
    await corpo.close();
    expect((await primeira).data, {'preco': 45});

    await _aguardarChamadas(transporte, 2);
    transporte.chamadas[1].resposta
        .complete(ResponseBody.fromString('{"erro":"teste"}', 503, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    }));
    await falha;

    final cancelar = CancelToken();
    final corpoCancelado = StreamController<Uint8List>();
    final terceira =
        dio.get<dynamic>('/cancelada', options: offline, cancelToken: cancelar);
    final cancelamento = expectLater(terceira, throwsA(_cancelamento));
    final quarta = dio.get<dynamic>('/ultima', options: offline);
    await _aguardarChamadas(transporte, 3);
    transporte.chamadas[2].resposta
        .complete(ResponseBody(corpoCancelado.stream, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    }));
    await Future<void>.delayed(const Duration(milliseconds: 1));
    cancelar.cancel('Teste de cancelamento durante download');
    await cancelamento;
    await corpoCancelado.close();
    await _aguardarChamadas(transporte, 4);
    transporte.chamadas[3].resposta
        .complete(ResponseBody.fromString('{"ok":true}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    }));
    expect((await quarta).data, {'ok': true});
  });

  test('somente uma preparacao chega ao transporte por vez', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final resultados = [
      _consumir(adapter.fetch(_consulta('/primeira'), null, null)),
      _consumir(adapter.fetch(_consulta('/segunda'), null, null)),
      _consumir(adapter.fetch(_consulta('/terceira'), null, null)),
    ];
    await _aguardarChamadas(transporte, 1);
    expect(transporte.chamadas, hasLength(1));
    expect(transporte.chamadas.single.options.path, '/primeira');

    transporte.chamadas[0].concluir('1');
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas, hasLength(2));
    expect(transporte.chamadas.last.options.path, '/segunda');
    transporte.chamadas[1].concluir('2');
    await _aguardarChamadas(transporte, 3);
    expect(transporte.chamadas, hasLength(3));
    expect(transporte.chamadas.last.options.path, '/terceira');
    transporte.chamadas[2].concluir('3');
    await tester.pump();
    await Future.wait(resultados);
    expect(transporte.maxPreparacoes, 1);
    adapter.close();
  });

  test('GET da tela e POST nao esperam preparacao lenta ou enfileirada',
      () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira =
        _consumir(adapter.fetch(_consulta('/offline-1'), null, null));
    final segunda =
        _consumir(adapter.fetch(_consulta('/offline-2'), null, null));
    await _aguardarChamadas(transporte, 1);
    final tela = _consumir(
        adapter.fetch(_consulta('/produtos', preparacao: false), null, null));
    // Mesmo com a marca de preparo, POST nao deve entrar na fila de GETs.
    final pedido = _consumir(
        adapter.fetch(_consulta('/pedido', method: 'POST'), null, null));
    await _aguardarChamadas(transporte, 3);
    expect(transporte.chamadas.map((e) => e.options.path),
        ['/offline-1', '/produtos', '/pedido']);
    transporte.chamadas[0].concluir('offline-1');
    await tester.pump();
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(3));
    transporte.chamadas[1].concluir('produtos');
    await tester.pump();
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(3));
    transporte.chamadas[2].concluir('pedido');
    await _aguardarChamadas(transporte, 4);
    expect(transporte.chamadas.last.options.path, '/offline-2');
    transporte.chamadas.last.concluir('offline-2');
    await tester.pump();
    await Future.wait([primeira, segunda, tela, pedido]);
    expect(transporte.maxPreparacoes, 1);
    adapter.close();
  });

  for (final cancelamentoComErro in [false, true]) {
    test(
        'cancelamento ${cancelamentoComErro ? 'com erro' : 'normal'} remove consulta em espera sem travar fila',
        () async {
      const tester = _RelogioReal();
      final transporte = _TransporteControlado();
      final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
      final cancelar = Completer<void>();
      final primeira =
          _consumir(adapter.fetch(_consulta('/primeira'), null, null));
      final cancelada =
          adapter.fetch(_consulta('/cancelada'), null, cancelar.future);
      final expectativa = expectLater(cancelada, throwsA(_cancelamento));
      final terceira =
          _consumir(adapter.fetch(_consulta('/terceira'), null, null));
      await _aguardarChamadas(transporte, 1);
      if (cancelamentoComErro) {
        cancelar.completeError(StateError('cancelada'));
      } else {
        cancelar.complete();
      }
      await tester.pump();
      await expectativa;
      expect(transporte.chamadas, hasLength(1));
      transporte.chamadas[0].concluir('1');
      await _aguardarChamadas(transporte, 2);
      expect(transporte.chamadas.map((e) => e.options.path),
          ['/primeira', '/terceira']);
      transporte.chamadas[1].concluir('3');
      await tester.pump();
      await Future.wait([primeira, terceira]);
      adapter.close();
    });
  }

  test('erro de transporte libera preparacao seguinte', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/falha'), null, null);
    final expectativa = expectLater(primeira, throwsA(isA<DioException>()));
    final segunda =
        _consumir(adapter.fetch(_consulta('/seguinte'), null, null));
    await _aguardarChamadas(transporte, 1);
    transporte.chamadas[0].resposta.completeError(DioException(
      requestOptions: transporte.chamadas[0].options,
      type: DioExceptionType.connectionError,
    ));
    await tester.pump();
    await expectativa;
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas.last.options.path, '/seguinte');
    transporte.chamadas.last.concluir('ok');
    await tester.pump();
    await segunda;
    adapter.close();
  });

  test('mesma URL sempre consulta novamente sem reaproveitar resposta',
      () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/produtos'), null, null);
    await _aguardarChamadas(transporte, 1);
    transporte.chamadas.single.concluir('antigo');
    await tester.pump();
    final resposta1 = await primeira;
    final dados1 = utf8.decodeStream(resposta1.stream);
    await tester.pump();
    expect(await dados1, 'antigo');
    final segunda = adapter.fetch(_consulta('/produtos'), null, null);
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas, hasLength(2));
    transporte.chamadas.last.concluir('novo');
    await tester.pump();
    final resposta2 = await segunda;
    final dados2 = utf8.decodeStream(resposta2.stream);
    await tester.pump();
    expect(await dados2, 'novo');
    expect(identical(resposta1, resposta2), isFalse);
    adapter.close();
  });

  test('vaga permanece durante corpo lento e nao antecipa consumo', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/corpo-pendente'), null, null);
    final segunda = _consumir(adapter.fetch(_consulta('/proxima'), null, null));
    await _aguardarChamadas(transporte, 1);
    final corpo = StreamController<Uint8List>();
    transporte.chamadas[0].resposta.complete(ResponseBody(corpo.stream, 200));
    await tester.pump();
    final resposta = await primeira;
    expect(corpo.isClosed, isFalse);
    expect(corpo.hasListener, isFalse);
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(1));
    final consumo = resposta.stream.drain<void>();
    corpo.add(Uint8List.fromList([1, 2]));
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(1));
    final fechamento = corpo.close();
    await tester.pump();
    await fechamento;
    await consumo;
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas.last.options.path, '/proxima');
    transporte.chamadas.last.concluir('ok');
    await tester.pump();
    await segunda;
    adapter.close();
  });

  test('cancelamento da consulta ativa e repassado ao transporte', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final cancelar = Completer<void>();
    final primeira = adapter.fetch(_consulta('/ativa'), null, cancelar.future);
    final expectativa = expectLater(primeira, throwsA(_cancelamento));
    final segunda =
        _consumir(adapter.fetch(_consulta('/seguinte'), null, null));
    await _aguardarChamadas(transporte, 1);
    expect(transporte.chamadas.single.cancelFuture, same(cancelar.future));
    cancelar.complete();
    transporte.chamadas.single.resposta.completeError(DioException(
      requestOptions: transporte.chamadas.single.options,
      type: DioExceptionType.cancel,
    ));
    await tester.pump();
    await expectativa;
    await _aguardarChamadas(transporte, 2);
    transporte.chamadas.last.concluir('seguinte');
    await tester.pump();
    await segunda;
    adapter.close();
  });

  test('download da tela retarda preparo mas nao bloqueia novo POST', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final tela =
        adapter.fetch(_consulta('/tela', preparacao: false), null, null);
    final preparo = _consumir(adapter.fetch(_consulta('/preparo'), null, null));
    await _aguardarChamadas(transporte, 1);
    final corpo = StreamController<Uint8List>();
    transporte.chamadas[0].resposta.complete(ResponseBody(corpo.stream, 200));
    final consumirTela = _consumir(tela);
    await tester.pump(respiro);
    expect(transporte.chamadas.map((c) => c.options.path), ['/tela']);

    final pedido = _consumir(
        adapter.fetch(_consulta('/pedido', method: 'POST'), null, null));
    await _aguardarChamadas(transporte, 2);
    expect(
        transporte.chamadas.map((c) => c.options.path), ['/tela', '/pedido']);
    transporte.chamadas.last.concluir('pedido');
    await tester.pump();
    await pedido;
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(2));

    final fechamento = corpo.close();
    await tester.pump();
    await fechamento;
    await consumirTela;
    await _aguardarChamadas(transporte, 3);
    expect(transporte.chamadas.last.options.path, '/preparo');
    transporte.chamadas.last.concluir('preparo');
    await tester.pump();
    await preparo;
    adapter.close();
  });

  test('stream preserva metadados identidade e pause resume cancel', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(
        _consulta('/stream')..responseType = ResponseType.stream, null, null);
    final segunda = _consumir(adapter.fetch(_consulta('/segunda'), null, null));
    await _aguardarChamadas(transporte, 1);
    var pausas = 0;
    var retomadas = 0;
    var cancelamentos = 0;
    var fechamentos = 0;
    final corpo = StreamController<Uint8List>(
      onPause: () => pausas++,
      onResume: () => retomadas++,
      onCancel: () => cancelamentos++,
    );
    final original = ResponseBody(corpo.stream, 206,
        statusMessage: 'Partial Content',
        headers: {
          'X-Teste': ['sim']
        },
        onClose: () => fechamentos++)
      ..extra['origem'] = 'transporte';
    transporte.chamadas.single.resposta.complete(original);
    await tester.pump();
    final resposta = await primeira;
    expect(resposta, same(original));
    expect(resposta.statusCode, 206);
    expect(resposta.headers['X-Teste'], ['sim']);
    expect(resposta.extra['origem'], 'transporte');
    expect(corpo.hasListener, isFalse);
    final assinatura = resposta.stream.listen((_) {});
    assinatura.pause();
    expect(pausas, 1);
    assinatura.resume();
    expect(retomadas, 1);
    await assinatura.cancel();
    expect(cancelamentos, 1);
    // O adaptador devolve o mesmo objeto; o fechamento nativo foi preservado.
    // ignore: invalid_use_of_internal_member
    resposta.close();
    expect(fechamentos, 1);
    await corpo.close();
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas.last.options.path, '/segunda');
    transporte.chamadas.last.concluir('ok');
    await tester.pump();
    await segunda;
    adapter.close();
  });

  test('erro no corpo libera a proxima preparacao', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/corpo-erro'), null, null);
    final segunda = _consumir(adapter.fetch(_consulta('/segunda'), null, null));
    await _aguardarChamadas(transporte, 1);
    final corpo = StreamController<Uint8List>();
    transporte.chamadas.single.resposta
        .complete(ResponseBody(corpo.stream, 200));
    await tester.pump();
    final resposta = await primeira;
    final expectativa =
        expectLater(resposta.stream.drain<void>(), throwsA(isA<StateError>()));
    corpo.addError(StateError('Corpo interrompido'));
    await tester.pump();
    await expectativa;
    await corpo.close();
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas.last.options.path, '/segunda');
    transporte.chamadas.last.concluir('ok');
    await tester.pump();
    await segunda;
    adapter.close();
  });

  test('token cancela corpo ativo sem liberar duas vezes a vaga', () async {
    const tester = _RelogioReal();
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final cancelar = Completer<void>();
    final primeira =
        adapter.fetch(_consulta('/primeira'), null, cancelar.future);
    final segunda = _consumir(adapter.fetch(_consulta('/segunda'), null, null));
    final terceira =
        _consumir(adapter.fetch(_consulta('/terceira'), null, null));
    await _aguardarChamadas(transporte, 1);
    final corpo = StreamController<Uint8List>();
    transporte.chamadas.single.resposta
        .complete(ResponseBody(corpo.stream, 200));
    final consumo = _consumir(primeira);
    await tester.pump();
    cancelar.complete();
    await _aguardarChamadas(transporte, 2);
    expect(transporte.chamadas.map((c) => c.options.path),
        ['/primeira', '/segunda']);

    // Simula transporte que conclui o corpo antigo depois do cancelamento.
    final fechamento = corpo.close();
    await tester.pump();
    await fechamento;
    await consumo;
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(2));
    transporte.chamadas[1].concluir('segunda');
    await tester.pump();
    await segunda;
    await _aguardarChamadas(transporte, 3);
    expect(transporte.chamadas.last.options.path, '/terceira');
    transporte.chamadas.last.concluir('terceira');
    await tester.pump();
    await terceira;
    adapter.close();
  });
}
