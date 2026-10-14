import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/socket/canal_atualizacao_online.dart';
import 'package:app/src/essencial/api/socket/descoberta_atualizacao_online.dart';
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _escopo = 'online|bigchef.com.br|2';

class _Descoberta extends DescobertaAtualizacaoOnline {
  ServidorAtualizacaoOnline? servidor;

  @override
  Future<ServidorAtualizacaoOnline?> descobrir({
    required String escopo,
    String ipPreferencial = '',
    int portaDescoberta = 9982,
    Duration timeout = const Duration(milliseconds: 900),
  }) async {
    expect(escopo, _escopo);
    return servidor;
  }
}

class _Central {
  _Central(this.http);

  final HttpServer http;
  final _mensagens = StreamController<Map<String, dynamic>>.broadcast();
  final _sockets = <WebSocket>[];

  static Future<_Central> abrir() async {
    final central =
        _Central(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));
    central.http.listen((request) async {
      expect(
          request.uri.queryParameters[CanalAtualizacaoOnline.parametroEscopo],
          _escopo);
      final socket = await WebSocketTransformer.upgrade(request);
      central._sockets.add(socket);
      socket.listen((mensagem) {
        final envelope = jsonDecode(mensagem as String) as Map;
        expect(envelope[CanalAtualizacaoOnline.chaveEscopo], _escopo);
        central._mensagens.add(
            Map<String, dynamic>.from(envelope['data']['customData'] as Map));
      });
    });
    return central;
  }

  ServidorAtualizacaoOnline descoberta(String nome) =>
      (ip: '127.0.0.1', porta: http.port, nome: nome);

  Future<Map<String, dynamic>> receber(String id) => _mensagens.stream
      .firstWhere((dados) => dados['idRequisicao'] == id)
      .timeout(const Duration(seconds: 3));

  Future<void> fechar() async {
    for (final socket in _sockets) {
      unawaited(socket.close());
    }
    await http.close(force: true);
    await _mensagens.close();
  }
}

String _comprovante(String id, {String tipo = '3', String computador = ''}) =>
    jsonEncode({
      'tipo': 'Delivery',
      'tipoImpressao': tipo,
      'protocoloImpressao': 2,
      'idRequisicao': id,
      'idEmpresa': '2',
      'idUsuario': '311',
      'nomedopc': computador,
      'numeroPedido': '',
      'comanda': 'Delivery 30758',
      'produtos': [
        {'id': '23615', 'nome': 'Coca Cola 350ml', 'quantidade': 1}
      ],
    });

Future<void> _conectar(Server server, _Central central) async {
  expect(await server.connect('127.0.0.1', '${central.http.port}'), isTrue);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'online',
        'servidor': '127.0.0.1',
        'porta': '9980',
      }),
    });
    app.usuarioProvedor = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '311', empresa: '2'));
    addTearDown(app.usuarioProvedor.dispose);
    final anterior = HttpOverrides.current;
    HttpOverrides.global = null;
    addTearDown(() => HttpOverrides.global = anterior);
  });

  test('comprovante sem computador usa a central descoberta e conserva o ID',
      () async {
    final central = await _Central.abrir();
    addTearDown(central.fechar);
    final descoberta = _Descoberta()
      ..servidor = central.descoberta('DESKTOP-IMNI62S');
    final server = Server(
        descobertaOnline: descoberta, obterEscopoOnline: () async => _escopo);
    addTearDown(server.dispose);
    await _conectar(server, central);

    final recebido = central.receber('comprovante-sem-pc');
    await server.enviarImpressoes([_comprovante('comprovante-sem-pc')]);
    final dados = await recebido;

    expect(dados['nomedopc'], 'DESKTOP-IMNI62S');
    expect(dados['idRequisicao'], 'comprovante-sem-pc');
    expect(dados['tipoImpressao'], '3');
    expect(dados['numeroPedido'], '');
    expect(dados['produtos'],
        (jsonDecode(_comprovante('comprovante-sem-pc')) as Map)['produtos']);
  });

  test('computador explicitamente configurado permanece no comprovante',
      () async {
    final central = await _Central.abrir();
    addTearDown(central.fechar);
    final descoberta = _Descoberta()
      ..servidor = central.descoberta('DESKTOP-IMNI62S');
    final server = Server(
        descobertaOnline: descoberta, obterEscopoOnline: () async => _escopo);
    addTearDown(server.dispose);
    await _conectar(server, central);

    final recebido = central.receber('comprovante-outro-pc');
    await server.enviarImpressoes([
      _comprovante('comprovante-outro-pc', computador: 'PC-CAIXA-2'),
    ]);

    expect((await recebido)['nomedopc'], 'PC-CAIXA-2');
  });

  test('preparo conserva o destino vazio mesmo com nome da central conhecido',
      () async {
    final central = await _Central.abrir();
    addTearDown(central.fechar);
    final descoberta = _Descoberta()
      ..servidor = central.descoberta('DESKTOP-IMNI62S');
    final server = Server(
        descobertaOnline: descoberta, obterEscopoOnline: () async => _escopo);
    addTearDown(server.dispose);
    await _conectar(server, central);

    final recebido = central.receber('preparo-sem-pc');
    await server.enviarImpressoes([
      _comprovante('preparo-sem-pc', tipo: '1'),
    ]);
    final dados = await recebido;

    expect(dados['nomedopc'], '');
    expect(dados['tipoImpressao'], '1');
    expect(dados['idRequisicao'], 'preparo-sem-pc');
  });

  test('comprovante salvo desconectado resolve o destino somente ao enviar',
      () async {
    final central = await _Central.abrir();
    addTearDown(central.fechar);
    final descoberta = _Descoberta()
      ..servidor = central.descoberta('DESKTOP-IMNI62S');
    final server = Server(
        descobertaOnline: descoberta, obterEscopoOnline: () async => _escopo);
    addTearDown(server.dispose);

    await server.enviarImpressoes([_comprovante('salvo-desconectado')]);
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.aguardandoEnvio);
    expect(server.filaImpressao.itens.single.dados['nomedopc'], '');

    final recebido = central.receber('salvo-desconectado');
    await _conectar(server, central);
    final dados = await recebido;

    expect(dados['nomedopc'], 'DESKTOP-IMNI62S');
    expect(dados['idRequisicao'], 'salvo-desconectado');
  });

  test('trocar central sem descoberta nao reutiliza o nome da conexao anterior',
      () async {
    final antiga = await _Central.abrir();
    addTearDown(antiga.fechar);
    final nova = await _Central.abrir();
    addTearDown(nova.fechar);
    final descoberta = _Descoberta()
      ..servidor = antiga.descoberta('CENTRAL-ANTIGA');
    final server = Server(
        descobertaOnline: descoberta, obterEscopoOnline: () async => _escopo);
    addTearDown(server.dispose);
    await _conectar(server, antiga);

    await server.disconnect();
    descoberta.servidor = null;
    await _conectar(server, nova);
    final recebido = nova.receber('comprovante-nova-central');
    await server.enviarImpressoes([_comprovante('comprovante-nova-central')]);
    final dados = await recebido;

    expect(dados['nomedopc'], '');
    expect(dados['idRequisicao'], 'comprovante-nova-central');
  });
}
