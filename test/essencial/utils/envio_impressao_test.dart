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
  setUp(() => SharedPreferences.setMockInitialValues({
        'conexao':
            jsonEncode({'tipoConexao': 'local', 'servidor': '', 'porta': ''}),
      }));

  test(
      'ACK antigo de recebimento nao apaga comprovante sem impressao confirmada',
      () async {
    final server = Server();
    addTearDown(server.dispose);
    await server.enviarImpressoes([mensagem('nao-impresso')]);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'idRequisicao': 'nao-impresso',
    });
    expect(server.filaImpressao.itens.single.id, 'nao-impresso');
    final restaurada = FilaImpressao();
    addTearDown(restaurada.dispose);
    await restaurada.carregar();
    expect(restaurada.itens.single.id, 'nao-impresso');
  });

  testWidgets(
      'consulta e recupera automaticamente envio perdido sem abrir pagina',
      (tester) async {
    var agora = DateTime(2026, 9, 11);
    final server = Server(agora: () => agora)..connected = true;
    addTearDown(server.dispose);
    final enviados = <Map<String, dynamic>>[];
    server.channel = CanalTeste(SaidaTeste((data) {
      enviados.add(Map<String, dynamic>.from(
          jsonDecode(data as String)['data']['customData']));
    }));
    await server.enviarImpressoes([mensagem('perdida')]);
    agora = agora.add(const Duration(seconds: 16));
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(enviados.map((e) => e['tipo']), ['Comanda', 'ConsultarImpressao']);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'naoEncontrada',
      'protocoloImpressao': 2,
      'idRequisicao': 'perdida',
    });
    await tester.pump();
    await tester.pump();
    final impressos = enviados.where((e) => e['tipoImpressao'] == '1').toList();
    expect(impressos, hasLength(2));
    expect(impressos.first, impressos.last);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'idRequisicao': 'perdida',
    });
    expect(server.filaImpressao.itens, isEmpty);
  });

  test(
      'retoma apos reinicio consultando comprovante ja enviado, sem segunda via',
      () async {
    final fila = FilaImpressao();
    await fila.registrar([mensagem('ja-enviada')]);
    await fila.iniciarEnvio('ja-enviada', agora: DateTime(2020));
    fila.dispose();
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    final enviados = <Map<String, dynamic>>[];
    server.channel = CanalTeste(SaidaTeste((data) {
      enviados.add(Map<String, dynamic>.from(
          jsonDecode(data as String)['data']['customData']));
    }));
    await server.processarImpressoesPendentes();
    expect(enviados.single['tipo'], 'ConsultarImpressao');
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'idRequisicao': 'ja-enviada',
      'produtos': [
        {'nome': 'Produto sem outros campos'}
      ],
    });
    expect(server.filaImpressao.itens, isEmpty);
    expect(enviados, hasLength(1));
  });

  test('impressao em processamento no servidor permanece na fila ate concluir',
      () async {
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    final enviados = <dynamic>[];
    server.channel = CanalTeste(SaidaTeste(enviados.add));
    await server.enviarImpressoes([mensagem('demorada')]);
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'processando',
      'protocoloImpressao': 2,
      'idRequisicao': 'demorada',
    });
    await server.processarImpressoesPendentes();
    expect(enviados, hasLength(1));
    expect(server.filaImpressao.itens.single.id, 'demorada');
  });

  test('impressao preparada nao e enviada antes do registro do pedido',
      () async {
    final server = Server()..connected = true;
    addTearDown(server.dispose);
    final enviados = <dynamic>[];
    server.channel = CanalTeste(SaidaTeste(enviados.add));
    await server.prepararImpressoes([mensagem('aguardando-api')]);
    await server.processarImpressoesPendentes();
    expect(enviados, isEmpty);
    expect(server.filaImpressao.itens.single.estado,
        EstadoImpressao.aguardandoPedido);
    await server.enviarImpressoes([mensagem('aguardando-api')]);
    expect(enviados, hasLength(1));
  });

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
        'protocoloImpressao': 2,
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

  test('falha na consulta da impressao inicia reconexao sem perder a fila',
      () async {
    var agora = DateTime(2026, 9, 11);
    final server = Server(agora: () => agora)..connected = true;
    addTearDown(server.dispose);
    var tentativas = 0;
    server.channel = CanalTeste(SaidaTeste((_) {
      if (++tentativas > 1) throw StateError('Canal interrompido');
    }));
    await server.enviarImpressoes([mensagem('consulta-interrompida')]);
    agora = agora.add(const Duration(seconds: 16));
    await server.processarImpressoesPendentes();
    expect(tentativas, 2);
    expect(server.connected, isFalse);
    expect(server.channel, isNull);
    expect(server.filaImpressao.itens.single.id, 'consulta-interrompida');

    final enviados = <Map<String, dynamic>>[];
    server.connected = true;
    server.channel = CanalTeste(SaidaTeste((data) {
      enviados.add(Map<String, dynamic>.from(
          jsonDecode(data as String)['data']['customData']));
    }));
    agora = agora.add(const Duration(seconds: 16));
    await server.processarImpressoesPendentes();
    expect(enviados.single['tipo'], 'ConsultarImpressao');
    expect(enviados.single['idRequisicao'], 'consulta-interrompida');
    await server.onData({
      'tipo': 'RespostaImpressao',
      'tipoResposta': 'impressao',
      'statusResposta': 'sucesso',
      'protocoloImpressao': 2,
      'idRequisicao': 'consulta-interrompida',
    });
    expect(server.filaImpressao.itens, isEmpty);
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
