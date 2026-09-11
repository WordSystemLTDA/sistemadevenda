import 'dart:convert';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'fila_impressao_test.dart' show mensagem;

class CanalTeste extends Fake implements WebSocketChannel {
  @override
  final WebSocketSink sink;
  CanalTeste(this.sink);
}

class SaidaTeste extends Fake implements WebSocketSink {
  final void Function(dynamic) aoEnviar;
  SaidaTeste(this.aoEnviar);
  @override
  void add(dynamic data) => aoEnviar(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('grava lote antes do socket e ACK imediato nao fica preso na fila',
      () async {
    final prefs = await SharedPreferences.getInstance();
    final server = Server();
    addTearDown(server.dispose);
    final recebidos = <String>[];
    final acks = <Future<void>>[];
    server.connected = true;
    server.hostname = 'cozinha';
    server.port = 123;
    server.channel = CanalTeste(SaidaTeste((data) {
      final pacote = jsonDecode(data as String)['data']['customData'];
      final id = pacote['idRequisicao'] as String;
      final gravado = jsonDecode(prefs.getString(FilaImpressao.chave)!) as List;
      expect(
          gravado.where((e) => jsonDecode(e['mensagem'])['idRequisicao'] == id),
          hasLength(1));
      recebidos.add(id);
      acks.add(server.onData({
        'tipo': 'RespostaImpressao',
        'tipoResposta': 'impressao',
        'statusResposta': 'sucesso',
        'idRequisicao': id
      }));
    }));
    await server.enviarImpressoes([mensagem('pizza'), mensagem('bebida')]);
    await Future.wait(acks);
    expect(recebidos, ['pizza', 'bebida']);
    expect(server.filaImpressao.itens, isEmpty);
  });

  test('offline conserva lote e sem ACK nao reimprime ao enviar outro pedido',
      () async {
    final server = Server();
    addTearDown(server.dispose);
    final recebidos = <String>[];
    await server.enviarImpressoes([mensagem('offline')]);
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.aguardandoEnvio);
    server.connected = true;
    server.channel = CanalTeste(SaidaTeste((data) {
      recebidos.add(jsonDecode(data as String)['data']['customData']
          ['idRequisicao'] as String);
    }));
    await server.enviarImpressoes([mensagem('nova')]);
    await server.enviarImpressoes([mensagem('outra')]);
    expect(recebidos, ['offline', 'nova', 'outra']);
    expect(server.filaImpressao.itens, hasLength(3));
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'erro',
      'idRequisicao': 'nova',
      'mensagemErro': 'Sem impressora'
    });
    expect(server.filaImpressao.itens.firstWhere((e) => e.id == 'nova').erro,
        'Sem impressora');
  });

  test('falha no socket nao tenta segunda via e mantem pendencia', () async {
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    var tentativas = 0;
    server.channel = CanalTeste(SaidaTeste((_) {
      tentativas++;
      throw StateError('Conexao perdida');
    }));
    await server.enviarImpressoes([mensagem('pizza')]);
    expect(tentativas, 1);
    expect(server.filaImpressao.itens.single.id, 'pizza');
    expect(server.filaImpressao.itens.single.estado, EstadoImpressao.erro);
  });

  test('nao envia pendencias de outra empresa na mesma conexao', () async {
    app.usuarioProvedor = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(empresa: '32'));
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    final recebidos = <String>[];
    server.channel = CanalTeste(SaidaTeste((data) {
      recebidos.add(jsonDecode(data as String)['data']['customData']
          ['idRequisicao'] as String);
    }));
    await server.enviarImpressoes([
      jsonEncode({...jsonDecode(mensagem('outra-empresa')), 'idEmpresa': '31'}),
      jsonEncode({...jsonDecode(mensagem('empresa-atual')), 'idEmpresa': '32'}),
    ]);
    expect(recebidos, ['empresa-atual']);
    expect(server.filaImpressao.itens.first.estado,
        EstadoImpressao.aguardandoEnvio);
  });

  test('mudanca de servidor nao envia pendencia para outra cozinha', () async {
    final server = Server()
      ..hostname = 'cozinha-A'
      ..port = 123;
    addTearDown(server.dispose);
    await server.enviarImpressoes([mensagem('antiga')]);
    server.hostname = 'cozinha-B';
    server.connected = true;
    final recebidos = <String>[];
    server.channel = CanalTeste(SaidaTeste((data) {
      recebidos.add(jsonDecode(data as String)['data']['customData']
          ['idRequisicao'] as String);
    }));
    await server.enviarImpressoes([mensagem('atual')]);
    expect(recebidos, ['atual']);
    expect(server.filaImpressao.itens.first.estado,
        EstadoImpressao.aguardandoEnvio);
  });
}
