import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class CanalSemResposta extends Fake implements WebSocketChannel {
  @override
  final SaidaSemResposta sink = SaidaSemResposta();
}

class SaidaSemResposta extends Fake implements WebSocketSink {
  final fechamento = Completer<void>();

  @override
  Future<void> close([int? closeCode, String? closeReason]) =>
      fechamento.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final anterior = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = anterior);
  });

  test('reconecta mesmo quando o canal antigo nao confirma fechamento',
      () async {
    final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final sockets = <WebSocket>[];
    local.listen((request) async {
      sockets.add(await WebSocketTransformer.upgrade(request));
    });
    final antigo = CanalSemResposta();
    final server = Server()..channel = antigo;
    addTearDown(() async {
      antigo.sink.fechamento.complete();
      server.dispose();
      for (final socket in sockets) {
        unawaited(socket.close());
      }
      await local.close(force: true);
    });

    expect(
        await server
            .connect('127.0.0.1', '${local.port}')
            .timeout(const Duration(seconds: 4)),
        isTrue);
    expect(server.connected, isTrue);
    expect(server.channel, isNot(same(antigo)));
    expect(await server.connect('127.0.0.1', '${local.port}'), isTrue);
    expect(sockets, hasLength(1));
    final recebeuDados = Completer<void>();
    server.addListener(() {
      if (server.nomedopc == 'cozinha' && !recebeuDados.isCompleted) {
        recebeuDados.complete();
      }
    });
    sockets.single.add(jsonEncode({'tipo': 'PC', 'nomedopc': 'cozinha'}));
    await recebeuDados.future.timeout(const Duration(seconds: 2));
  });

  test('troca de servidor abandona tentativa antiga ainda sem resposta',
      () async {
    final antigo = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final recebeu = Completer<void>();
    antigo.listen((_) => recebeu.complete());
    final novo = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    WebSocket? socket;
    novo.listen((request) async {
      socket = await WebSocketTransformer.upgrade(request);
    });
    final server = Server();
    addTearDown(() async {
      server.dispose();
      if (socket != null) unawaited(socket!.close());
      await antigo.close(force: true);
      await novo.close(force: true);
    });

    final primeira = server.connect('127.0.0.1', '${antigo.port}');
    await recebeu.future;
    final repetida = server.connect('127.0.0.1', '${antigo.port}');
    expect(
        await server
            .connect('127.0.0.1', '${novo.port}')
            .timeout(const Duration(seconds: 3)),
        isTrue);
    expect(await primeira, isFalse);
    expect(await repetida, isFalse);
    expect(server.connected, isTrue);
    expect(server.port, novo.port);
  });

  test('desconectar durante abertura nao permite conexao tardia', () async {
    final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final recebeu = Completer<void>();
    local.listen((_) => recebeu.complete());
    final server = Server();
    addTearDown(() async {
      server.dispose();
      await local.close(force: true);
    });

    final tentativa = server.connect('127.0.0.1', '${local.port}');
    await recebeu.future;
    await server.disconnect();
    expect(await tentativa.timeout(const Duration(seconds: 3)), isFalse);
    expect(server.connected, isFalse);
    expect(server.channel, isNull);
  });

  test('servidor que nao responde libera nova tentativa apos timeout',
      () async {
    final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var responder = false;
    WebSocket? socket;
    local.listen((request) async {
      if (responder) socket = await WebSocketTransformer.upgrade(request);
    });
    final server = Server();
    addTearDown(() async {
      server.dispose();
      if (socket != null) unawaited(socket!.close());
      await local.close(force: true);
    });
    expect(
        await server
            .connect('127.0.0.1', '${local.port}')
            .timeout(const Duration(seconds: 10)),
        isFalse);
    responder = true;
    expect(
        await server
            .connect('127.0.0.1', '${local.port}')
            .timeout(const Duration(seconds: 3)),
        isTrue);
    expect(server.connected, isTrue);
  });
}
