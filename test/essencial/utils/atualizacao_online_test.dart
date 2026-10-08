import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/socket/canal_atualizacao_online.dart';
import 'package:app/src/essencial/api/socket/descoberta_atualizacao_online.dart';
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/url_imagem.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'fila_impressao_test.dart' show mensagem;

class FilaContandoLeituras extends FilaImpressao {
  int leituras = 0;

  @override
  Future<void> carregar() async {
    leituras++;
    await super.carregar();
  }
}

class DescobertaSimulada extends DescobertaAtualizacaoOnline {
  ServidorAtualizacaoOnline? servidor;
  int tentativas = 0;
  @override
  Future<ServidorAtualizacaoOnline?> descobrir({
    required String escopo,
    String ipPreferencial = '',
    int portaDescoberta = 9982,
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    tentativas++;
    return servidor;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const escopo = 'online|bigchef.com.br|2';
  setUp(() {
    app.usuarioProvedor = UsuarioProvedor();
    addTearDown(app.usuarioProvedor.dispose);
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'online',
        'servidor': '192.168.2.115',
        'porta': '9980',
      })
    });
    final anterior = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = anterior);
  });

  test('online sem login nao abre socket nem descobre outra empresa', () async {
    final descoberta = DescobertaSimulada();
    final server = Server(descobertaOnline: descoberta);
    addTearDown(server.dispose);
    expect(await server.connect('127.0.0.1', '9980'), isFalse);
    expect(server.channel, isNull);
    expect(descoberta.tentativas, 0);
  });

  test('descoberta UDP reenvia consulta perdida e preserva o escopo', () async {
    final udp = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
    final recebeu = Completer<Map<String, dynamic>>();
    var consultas = 0;
    udp.listen((evento) {
      if (evento != RawSocketEvent.read) return;
      final datagrama = udp.receive();
      if (datagrama == null) return;
      final requisicao = Map<String, dynamic>.from(
          jsonDecode(utf8.decode(datagrama.data)) as Map);
      if (++consultas == 1) return;
      if (!recebeu.isCompleted) recebeu.complete(requisicao);
      udp.send(
          utf8.encode(jsonEncode({
            'type': 'discover_sistemarestaurante_server_response_v1',
            'payload': {
              'ipAddress': '127.0.0.1',
              'webSocketPort': 9980,
              'name': 'PC Online',
              'capabilities': {
                CanalAtualizacaoOnline.chaveEscopo: escopo,
                'somente_atualizacao': true
              },
            },
          })),
          datagrama.address,
          datagrama.port);
    });
    addTearDown(udp.close);
    final encontrado = await DescobertaAtualizacaoOnline().descobrir(
      escopo: escopo,
      ipPreferencial: '127.0.0.1',
      portaDescoberta: udp.port,
    );
    expect(
        (await recebeu.future
            .timeout(const Duration(seconds: 2)))['requesterMetadata'],
        {CanalAtualizacaoOnline.chaveEscopo: escopo});
    expect(encontrado, (ip: '127.0.0.1', porta: 9980, nome: 'PC Online'));
    expect(consultas, greaterThan(1));
  });

  test('descoberta isola empresa e API; ambiguidade exige IP escolhido', () {
    Map<String, dynamic> resposta(String ip, String id) => {
          'ipAddress': ip,
          'webSocketPort': 9980,
          'name': ip,
          'capabilities': {
            CanalAtualizacaoOnline.chaveEscopo: id,
            'somente_atualizacao': true
          },
        };
    final respostas = [
      resposta('192.168.0.2', escopo),
      resposta('192.168.0.3', 'online|bigchef.com.br|3'),
      resposta('192.168.0.4', 'online|outra-api.com|2')
    ];
    expect(
        DescobertaAtualizacaoOnline.selecionar(respostas, escopo: escopo)?.ip,
        '192.168.0.2');
    respostas.add(resposta('192.168.0.5', escopo));
    expect(DescobertaAtualizacaoOnline.selecionar(respostas, escopo: escopo),
        isNull);
    expect(
        DescobertaAtualizacaoOnline.selecionar(respostas,
                escopo: escopo, ipPreferencial: '192.168.0.5')
            ?.ip,
        '192.168.0.5');
  });

  test('socket online usa PC descoberto sem mudar API ou imagens', () async {
    final prefs = await SharedPreferences.getInstance();
    final impressaoLegada = mensagem('fila-local-anterior');
    final impressaoSemId =
        jsonEncode({'tipo': 'Comanda', 'tipoImpressao': '1'});
    await prefs.setStringList('fila_mensagens_socket_pendentes', [
      impressaoLegada,
      impressaoSemId,
      jsonEncode({
        'tipo': 'Mesa',
        CanalAtualizacaoOnline.chaveEscopo: 'online|bigchef.com.br|3'
      }),
    ]);
    final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final mensagens = StreamController<Map<String, dynamic>>();
    WebSocket? socket;
    http.listen((request) async {
      expect(
          request.uri.queryParameters[CanalAtualizacaoOnline.parametroEscopo],
          escopo);
      socket = await WebSocketTransformer.upgrade(request);
      socket!.listen((data) => mensagens
          .add(Map<String, dynamic>.from(jsonDecode(data as String) as Map)));
    });
    final descoberta = DescobertaSimulada()
      ..servidor = (ip: '127.0.0.1', porta: http.port, nome: 'PC Online');
    final fila = FilaContandoLeituras();
    final server = Server(
        filaImpressao: fila,
        obterEscopoOnline: () async => escopo,
        descobertaOnline: descoberta);
    addTearDown(() async {
      server.dispose();
      await socket?.close();
      await http.close(force: true);
      await mensagens.close();
    });
    final entrada = mensagens.stream.asBroadcastStream();
    final primeira = entrada.first;
    expect(await server.connect('192.168.2.115', '9980'), isTrue);
    expect(server.hostname, '127.0.0.1');
    final handshake = await primeira.timeout(const Duration(seconds: 3));
    expect(handshake[CanalAtualizacaoOnline.chaveEscopo], escopo);
    final proxima = entrada.first;
    expect(server.write(jsonEncode({'tipo': 'Mesa', 'id': '88'})), isTrue);
    final aviso = await proxima.timeout(const Duration(seconds: 3));
    expect(aviso['data']['customData'], {'tipo': 'Mesa'});
    expect(server.write(jsonEncode({'tipo': 'Mesa', 'tipoImpressao': '1'})),
        isFalse);
    await server.enviarImpressoes([mensagem('nao-imprimir-online')]);
    final leituras = fila.leituras;
    await Future<void>.delayed(const Duration(milliseconds: 180));
    expect(fila.itens.map((item) => item.id),
        unorderedEquals(['fila-local-anterior', 'nao-imprimir-online']));
    // Um lote anterior pode pedir uma unica continuacao enquanto o novo e salvo.
    expect(fila.leituras, lessThanOrEqualTo(leituras + 1),
        reason: 'O canal de avisos nao deve repetir lotes de impressao.');
    expect(prefs.getStringList('fila_mensagens_socket_pendentes'),
        [impressaoSemId]);
    expect((await Apis().getConexao()).servidor,
        startsWith('https://bigchef.com.br/'));
    expect(await UrlImagem.obterBaseHostImagens(), 'https://bigchef.com.br');
    final atualizacoes = <String>[];
    server.aoAtualizarDados = atualizacoes.add;
    Map<String, dynamic> envelope(String id, String tipo) => {
          'type': 'customMessage',
          CanalAtualizacaoOnline.chaveEscopo: id,
          'data': {
            'customData': {'tipo': tipo}
          },
        };
    await server
        .onData(jsonEncode(envelope('online|bigchef.com.br|3', 'Comanda')));
    await server.onData(jsonEncode(envelope(escopo, 'CancelarImpressao')));
    expect(atualizacoes, isEmpty);
    await server.onData(jsonEncode(envelope(escopo, 'Delivery')));
    expect(atualizacoes, ['Delivery']);
    await server.disconnect();
    expect(server.connected, isFalse);
  });
}
