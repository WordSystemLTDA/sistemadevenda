import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _mensagem() => jsonEncode({
      'idRequisicao': 'entregador-243',
      'tipo': 'Delivery',
      'tipoImpressao': '3',
      'protocoloImpressao': 2,
      'idEmpresa': '34',
      'idUsuario': '289',
      'comanda': 'Delivery 243',
      'total': '49.00',
      'produtos': [
        {'nome': 'Pizza', 'valorVenda': '46.00', 'quantidade': 1}
      ],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'conexao':
          jsonEncode({'tipoConexao': 'local', 'servidor': '', 'porta': ''}),
    });
    app.usuarioProvedor = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(empresa: '34'));
    final anterior = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = anterior);
  });

  test(
      'offline conserva comprovante, reconecta uma vez e remove somente apos ACK',
      () async {
    final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    var disponivel = false;
    final sockets = <WebSocket>[];
    final recebidos = <Map<String, dynamic>>[];
    final recebeu = Completer<void>();
    local.listen((request) async {
      if (!disponivel) {
        request.response.statusCode = HttpStatus.serviceUnavailable;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((texto) {
        final m = (jsonDecode(texto as String) as Map)['data']?['customData'];
        if (m is Map && m['tipoImpressao'] != null) {
          recebidos.add(Map<String, dynamic>.from(m));
          if (!recebeu.isCompleted) recebeu.complete();
        }
      });
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'conexao',
        jsonEncode({
          'tipoConexao': 'local',
          'servidor': '127.0.0.1',
          'porta': '${local.port}',
        }));
    final server = Server();
    addTearDown(() async {
      server.dispose();
      for (final socket in sockets) {
        unawaited(socket.close());
      }
      await local.close(force: true);
    });
    await server.filaImpressao
        .registrar([_mensagem()], servidor: '127.0.0.1:${local.port}');
    await server.filaImpressao
        .registrarErro('entregador-243', 'Impressora indisponivel');
    await expectLater(
        server.reenviarImpressao('entregador-243'),
        throwsA(isA<StateError>()
            .having((e) => e.message, 'mensagem', contains('continua salva'))));
    final salvo = server.filaImpressao.itens.single;
    expect(salvo.estado, EstadoImpressao.aguardandoEnvio);
    expect(salvo.dados['retomadaImpressao'], isNotEmpty);
    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.carregar();
    expect(restaurada.itens.single.mensagem, salvo.mensagem);
    expect(recebidos, isEmpty);

    // Outra tentativa offline nao cria outra via nem troca sua identidade.
    await expectLater(
        server.reenviarImpressao('entregador-243'), throwsStateError);
    expect(server.filaImpressao.itens.single.mensagem, salvo.mensagem);
    disponivel = true;
    final primeira = server.reenviarImpressao('entregador-243');
    final repetida = server.reenviarImpressao('entregador-243');
    expect(identical(primeira, repetida), isTrue);
    await Future.wait([primeira, repetida]);
    await recebeu.future.timeout(const Duration(seconds: 3));
    expect(recebidos, hasLength(1));
    expect(recebidos.single['idRequisicao'], 'entregador-243');
    expect(recebidos.single['tipoImpressao'], '3');
    expect(recebidos.single['retomadaImpressao'],
        salvo.dados['retomadaImpressao']);
    expect(recebidos.single['produtos'], jsonDecode(_mensagem())['produtos']);
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.semConfirmacao);
    await server.processarImpressoesPendentes();
    expect(recebidos, hasLength(1));

    final confirmou = Completer<void>();
    server.filaImpressao.addListener(() {
      if (server.filaImpressao.itens.isEmpty && !confirmou.isCompleted) {
        confirmou.complete();
      }
    });
    sockets.single.add(jsonEncode({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'idRequisicao': 'entregador-243',
      'idEmpresa': '34',
    }));
    await confirmou.future.timeout(const Duration(seconds: 3));
    expect(server.filaImpressao.itens, isEmpty);
    final aposAck = FilaImpressao();
    addTearDown(aposAck.dispose);
    await aposAck.carregar();
    expect(aposAck.itens, isEmpty);
  });

  test('reenvio bloqueia outra empresa sem alterar a pendencia', () async {
    final server = Server();
    addTearDown(server.dispose);
    await server.filaImpressao.registrar([_mensagem()]);
    app.usuarioProvedor = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(empresa: '35'));
    await expectLater(
        server.reenviarImpressao('entregador-243'), throwsStateError);
    expect(server.filaImpressao.itens.single.mensagem, _mensagem());
  });

  test('servidor que recusa conexao explica o motivo e conserva o comprovante',
      () async {
    final local = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    local.listen((request) async {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'conexao',
        jsonEncode({
          'tipoConexao': 'local',
          'servidor': '127.0.0.1',
          'porta': '${local.port}',
        }));
    final server = Server();
    addTearDown(() async {
      server.dispose();
      await local.close(force: true);
    });
    await server.filaImpressao.registrar([_mensagem()]);
    await expectLater(
        server.reenviarImpressao('entregador-243'),
        throwsA(isA<StateError>().having((erro) => erro.message, 'mensagem',
            contains('recusou a conexão'))));
    expect(server.connected, isFalse);
    expect(server.erroConexao, contains('empresa'));
    expect(server.filaImpressao.itens.single.mensagem, _mensagem());
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.aguardandoEnvio);
  });

  for (final estado in [
    EstadoImpressao.aguardandoPedido,
    EstadoImpressao.cancelamentoPendente
  ]) {
    test('reenvio nao libera impressao em ${estado.name}', () async {
      final server = Server();
      addTearDown(server.dispose);
      await server.filaImpressao.registrar([_mensagem()], estado: estado);
      await expectLater(
          server.reenviarImpressao('entregador-243'), throwsStateError);
      expect(server.filaImpressao.itens.single.estado, estado);
      expect(server.filaImpressao.itens.single.mensagem, _mensagem());
    });
  }
}
