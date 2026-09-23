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

void main() {
  const respiro = Duration(milliseconds: 120);

  testWidgets('somente uma preparacao chega ao transporte por vez',
      (tester) async {
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final resultados = [
      adapter.fetch(_consulta('/primeira'), null, null),
      adapter.fetch(_consulta('/segunda'), null, null),
      adapter.fetch(_consulta('/terceira'), null, null),
    ];
    await tester.pump();
    expect(transporte.chamadas, hasLength(1));
    expect(transporte.chamadas.single.options.path, '/primeira');

    transporte.chamadas[0].concluir('1');
    await tester.pump();
    expect(transporte.chamadas, hasLength(1));
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(2));
    expect(transporte.chamadas.last.options.path, '/segunda');
    transporte.chamadas[1].concluir('2');
    await tester.pump();
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(3));
    expect(transporte.chamadas.last.options.path, '/terceira');
    transporte.chamadas[2].concluir('3');
    await Future.wait(resultados);
    expect(transporte.maxPreparacoes, 1);
    adapter.close();
  });

  testWidgets('GET da tela e POST nao esperam preparacao lenta ou enfileirada',
      (tester) async {
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/offline-1'), null, null);
    final segunda = adapter.fetch(_consulta('/offline-2'), null, null);
    await tester.pump();
    final tela =
        adapter.fetch(_consulta('/produtos', preparacao: false), null, null);
    // Mesmo com a marca de preparo, POST nao deve entrar na fila de GETs.
    final pedido =
        adapter.fetch(_consulta('/pedido', method: 'POST'), null, null);
    await tester.pump();
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
    await tester.pump();
    await tester.pump(respiro);
    expect(transporte.chamadas.last.options.path, '/offline-2');
    transporte.chamadas.last.concluir('offline-2');
    await Future.wait([primeira, segunda, tela, pedido]);
    expect(transporte.maxPreparacoes, 1);
    adapter.close();
  });

  for (final cancelamentoComErro in [false, true]) {
    testWidgets(
        'cancelamento ${cancelamentoComErro ? 'com erro' : 'normal'} remove consulta em espera sem travar fila',
        (tester) async {
      final transporte = _TransporteControlado();
      final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
      final cancelar = Completer<void>();
      final primeira = adapter.fetch(_consulta('/primeira'), null, null);
      final cancelada =
          adapter.fetch(_consulta('/cancelada'), null, cancelar.future);
      final expectativa = expectLater(cancelada, throwsA(_cancelamento));
      final terceira = adapter.fetch(_consulta('/terceira'), null, null);
      await tester.pump();
      if (cancelamentoComErro) {
        cancelar.completeError(StateError('cancelada'));
      } else {
        cancelar.complete();
      }
      await tester.pump();
      await expectativa;
      expect(transporte.chamadas, hasLength(1));
      transporte.chamadas[0].concluir('1');
      await tester.pump();
      await tester.pump(respiro);
      expect(transporte.chamadas.map((e) => e.options.path),
          ['/primeira', '/terceira']);
      transporte.chamadas[1].concluir('3');
      await Future.wait([primeira, terceira]);
      adapter.close();
    });
  }

  testWidgets('erro de transporte libera preparacao seguinte', (tester) async {
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/falha'), null, null);
    final expectativa = expectLater(primeira, throwsA(isA<DioException>()));
    final segunda = adapter.fetch(_consulta('/seguinte'), null, null);
    await tester.pump();
    transporte.chamadas[0].resposta.completeError(DioException(
      requestOptions: transporte.chamadas[0].options,
      type: DioExceptionType.connectionError,
    ));
    await tester.pump();
    await expectativa;
    await tester.pump(respiro);
    expect(transporte.chamadas.last.options.path, '/seguinte');
    transporte.chamadas.last.concluir('ok');
    await segunda;
    adapter.close();
  });

  testWidgets('mesma URL sempre consulta novamente sem reaproveitar resposta',
      (tester) async {
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/produtos'), null, null);
    await tester.pump();
    transporte.chamadas.single.concluir('antigo');
    final resposta1 = await primeira;
    final segunda = adapter.fetch(_consulta('/produtos'), null, null);
    await tester.pump(respiro);
    expect(transporte.chamadas, hasLength(2));
    transporte.chamadas.last.concluir('novo');
    final resposta2 = await segunda;
    expect(await utf8.decodeStream(resposta1.stream), 'antigo');
    expect(await utf8.decodeStream(resposta2.stream), 'novo');
    expect(identical(resposta1, resposta2), isFalse);
    adapter.close();
  });

  testWidgets('vaga termina nos headers sem aguardar consumo do corpo',
      (tester) async {
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final primeira = adapter.fetch(_consulta('/corpo-pendente'), null, null);
    final segunda = adapter.fetch(_consulta('/proxima'), null, null);
    await tester.pump();
    final corpo = StreamController<Uint8List>();
    transporte.chamadas[0].resposta.complete(ResponseBody(corpo.stream, 200));
    final resposta = await primeira;
    expect(corpo.isClosed, isFalse);
    await tester.pump(respiro);
    expect(transporte.chamadas.last.options.path, '/proxima');
    transporte.chamadas.last.concluir('ok');
    await segunda;
    final consumo = resposta.stream.drain<void>();
    await corpo.close();
    await consumo;
    adapter.close();
  });

  testWidgets('cancelamento da consulta ativa e repassado ao transporte',
      (tester) async {
    final transporte = _TransporteControlado();
    final adapter = AdaptadorHttpPrioritario(transporte, respiro: respiro);
    final cancelar = Completer<void>();
    final primeira = adapter.fetch(_consulta('/ativa'), null, cancelar.future);
    final expectativa = expectLater(primeira, throwsA(_cancelamento));
    final segunda = adapter.fetch(_consulta('/seguinte'), null, null);
    await tester.pump();
    expect(transporte.chamadas.single.cancelFuture, same(cancelar.future));
    cancelar.complete();
    transporte.chamadas.single.resposta.completeError(DioException(
      requestOptions: transporte.chamadas.single.options,
      type: DioExceptionType.cancel,
    ));
    await tester.pump();
    await expectativa;
    await tester.pump(respiro);
    transporte.chamadas.last.concluir('seguinte');
    await segunda;
    adapter.close();
  });
}
