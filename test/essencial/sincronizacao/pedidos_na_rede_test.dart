import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/pedidos_na_rede.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/impressao_preparo_test.dart' show produto;

class SocketRedeTeste extends Server {
  @override
  String? get escopoPedidosRede => 'online|bigchef.com.br|2';
  final envios = <Map<String, dynamic>>[];
  @override
  bool enviarPedidoRede(Map<String, dynamic> mensagem) {
    envios.add(mensagem);
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  const escopo = 'online|bigchef.com.br|2';
  const executor = 'preparo-11111111111111111111111111111111';
  late Directory pasta;
  late BancoLocal banco;
  late UsuarioProvedor usuario;
  late SocketRedeTeste socket;
  late PedidosNaRede rede;
  late String alvo;
  late Map<String, Object?> op;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pasta = await Directory.systemTemp.createTemp('pedido-rede-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/db');
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '2', nome: 'Garcom'));
    socket = SocketRedeTeste()
      ..connected = true
      ..executorPedidosRede = executor;
    alvo = BancoLocal.escopo('https://bigchef.com.br/api41/', '2', '1');
    rede = PedidosNaRede(banco, socket, usuario)
      ..destino = 'PC:9980'
      ..configurar(alvo, escopo);
    await banco.gravar(
        'estado:$alvo', jsonEncode({'pedidos_rede_sem_internet': 1}));
    final p = produto(computador: '')..valorVenda = '25';
    op = {
      'id': BancoLocal.novoId(),
      'escopo': alvo,
      'atendimento': '10',
      'acao': 'produtos',
      'estado': 'pendente',
      'tentativas': 0,
      'criado': 1,
      'destino': 'PC:9980',
      'dados': jsonEncode({
        'tipo': 'mesa',
        'id_mesa': '3',
        'empresa': '2',
        'id_usuario': '1',
        'produtos': [p.toMap()]
      }),
      'impressoes': jsonEncode([
        jsonEncode({
          'tipo': 'Mesa',
          'tipoImpressao': '1',
          'protocoloImpressao': 2,
          'idRequisicao': 'cozinha-${BancoLocal.novoId()}',
          'idEmpresa': '2',
          'produtos': [p.toMap()],
        })
      ]),
    };
    await banco.db.insert('operacoes', op);
  });
  tearDown(() async {
    rede.dispose();
    await rede.processar();
    socket.dispose();
    usuario.dispose();
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  test(
      'ACK da LAN conserva pendencia financeira; reinicio confirma sem perder copia',
      () async {
    final id = op['id'] as String;
    expect(await rede.preparar(op), executor);
    await banco.atualizarOperacao(id, {'tentativas': 1, 'erro': 'Sem API'});
    await rede.processar();
    final mensagem = socket.envios.single;
    expect(mensagem['pedido']['tipoAtendimento'], 'mesa');
    expect(mensagem['impressoes'].single['idOperacaoRede'], id);
    expect(mensagem['impressoes'].single['pedidoRedeSemInternet'], isNull);
    // Perda do ACK repete exatamente o retrato e o mesmo ID de impressao.
    await rede.processar();
    expect(socket.envios.last, mensagem);
    await rede.receber({
      'idEmpresa': '2',
      'idOperacaoRede': id,
      'executorImpressaoRede': executor,
      'estado': 'recebido'
    });
    await rede.processar();
    expect(socket.envios, hasLength(2));
    expect((await banco.operacoes(alvo)).single['estado'], 'pendente');
    rede.dispose();
    rede = PedidosNaRede(banco, socket, usuario)..configurar(alvo, escopo);
    expect(await rede.preparar((await banco.operacoes(alvo)).single), executor);
    await banco.atualizarOperacao(
        id, {'estado': 'concluido', 'resposta': '{"sucesso":true}'});
    await rede.processar();
    expect(socket.envios.last['tipo'], 'ConfirmarPedidoRede');
    await rede.receber({
      'idEmpresa': '2',
      'idOperacaoRede': id,
      'executorImpressaoRede': executor,
      'estado': 'confirmado'
    });
    await rede.processar();
    expect(socket.envios, hasLength(3));
  });

  test('modo Local, API antiga e operacao ja tentada mantem caminho anterior',
      () async {
    rede.configurar(alvo, null);
    expect(await rede.preparar(op), isNull);
    rede.configurar(alvo, escopo);
    await banco.gravar('estado:$alvo', '{}');
    expect(await rede.preparar(op), isNull);
    await banco.gravar('estado:$alvo', '{"pedidos_rede_sem_internet":1}');
    expect(await rede.preparar({...op, 'tentativas': 1}), isNull);
    expect(
        await banco.ler(PedidosNaRede.chave(alvo, op['id'] as String)), isNull);
  });

  test('canal conhecido sobrevive a reinicio e queda temporaria do socket',
      () async {
    await rede
        .processar(); // Aprende a identidade do PC, antes de qualquer POST.
    rede.dispose();
    rede = PedidosNaRede(banco, socket, usuario)
      ..destino = 'PC:9980'
      ..configurar(alvo, escopo)
      ..apiIndisponivel = true;
    socket.connected = false;
    socket.executorPedidosRede = null;
    expect(await rede.preparar(op), executor);
    await rede.processar();
    expect(socket.envios, isEmpty);
    socket.connected = true;
    socket.executorPedidosRede = executor;
    await rede.processar();
    expect(socket.envios.single['idOperacaoRede'], op['id']);
    // Uma configuracao escolhendo outro PC nao herda a reserva anterior.
    socket.connected = false;
    rede.destino = 'outro-PC:9980';
    final outro = {
      ...op,
      'id': BancoLocal.novoId(),
      'destino': 'outro-PC:9980'
    };
    await banco.db.insert('operacoes', outro);
    expect(await rede.preparar(outro), isNull);
  });

  test('outro PC ou outra empresa nao recebe nem confirma a copia', () async {
    final id = op['id'] as String;
    await rede.preparar(op);
    rede.apiIndisponivel = true;
    socket.executorPedidosRede = 'preparo-22222222222222222222222222222222';
    await rede.processar();
    expect(socket.envios, isEmpty);
    await rede.receber({
      'idEmpresa': '2',
      'idOperacaoRede': id,
      'executorImpressaoRede': socket.executorPedidosRede,
      'estado': 'recebido'
    });
    socket.executorPedidosRede = executor;
    await rede.receber({
      'idEmpresa': '3',
      'idOperacaoRede': id,
      'executorImpressaoRede': executor,
      'estado': 'recebido'
    });
    await rede.processar();
    expect(socket.envios, hasLength(1));
    rede.configurar('outra conta', 'online|bigchef.com.br|3');
    await rede.processar();
    expect(socket.envios, hasLength(1));
  });

  test('varios pedidos novos chegam a cozinha apesar de API bloqueada',
      () async {
    final segundo = {...op, 'id': BancoLocal.novoId(), 'atendimento': '11'};
    await banco.db.insert('operacoes', segundo);
    await rede.preparar(op);
    await rede.preparar(segundo);
    rede.apiIndisponivel = true;
    await rede.processar();
    expect(socket.envios, hasLength(2));
    await banco.atualizarOperacao(
        op['id'] as String, {'estado': 'conflito', 'erro': 'Mesa encerrada'});
    await rede.processar();
    expect(
        socket.envios
            .where((m) => m['tipo'] == 'ConfirmarPedidoRede')
            .single['conflito'],
        isTrue);
  });

  test(
      'Delivery guarda destinos e montagem de preparo com IDs estaveis antes do POST',
      () async {
    op = {...op, 'acao': 'delivery', 'impressoes': '[]'};
    await banco.db
        .update('operacoes', op, where: 'id = ?', whereArgs: [op['id']]);
    expect(await rede.preparar(op), executor);
    final atual = (await banco.operacoes(alvo)).single;
    final preparos =
        List<String>.from(jsonDecode(atual['impressoes'] as String));
    expect(preparos, isEmpty);
    final rota = jsonDecode(
            (await banco.ler(PedidosNaRede.chave(alvo, op['id'] as String)))!)
        as Map;
    final preparo = (rota['mensagem']['impressoes'] as List).single as Map;
    expect(preparo['idRequisicao'], 'rede-${op['id']}-0');
    expect(preparo['tipo'], 'Delivery');
    expect(preparo['nomedopc'], isNull);
    expect(preparo['produtos'].single['nome'], contains('Porcao inteira'));
    expect(await rede.preparar(atual), executor);
    expect((await banco.operacoes(alvo)).single['impressoes'],
        atual['impressoes']);
  });
  test(
      'Delivery so confirma preparo depois do ACK do PC e conserva intencao no reinicio',
      () async {
    op = {...op, 'acao': 'delivery', 'impressoes': '[]'};
    await banco.db
        .update('operacoes', op, where: 'id = ?', whereArgs: [op['id']]);
    await rede.preparar(op);
    final id = op['id'] as String;
    final resposta = {
      'idEmpresa': '2',
      'idOperacaoRede': id,
      'executorImpressaoRede': executor,
      'estado': 'recebido',
      'etapaDelivery': 'aguardando'
    };
    await rede.receber(resposta);
    final futuro = rede.prepararDelivery('delivery-local:$id');
    for (var i = 0;
        i < 100 &&
            !socket.envios.any((m) => m['tipo'] == 'PrepararDeliveryRede');
        i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(socket.envios.last['tipo'], 'PrepararDeliveryRede');
    final antes =
        jsonDecode((await banco.ler(PedidosNaRede.chave(alvo, id)))!) as Map;
    expect(antes['etapaDelivery'], 'aguardando');
    expect(antes['preparoSolicitado'], isTrue);
    // O POST pode confirmar a venda enquanto o ACK do preparo ainda esta em voo.
    await banco.atualizarOperacao(id, {
      'estado': 'concluido',
      'resposta': '{"sucesso":true,"idDelivery":"77"}'
    });
    await rede.processar();
    expect(socket.envios.last['tipo'], 'ConfirmarPedidoRede');
    expect(socket.envios.last['preparoSolicitado'], isTrue);
    await rede.receber({...resposta, 'etapaDelivery': 'preparando'});
    await futuro;
    await rede.processar();
    expect(socket.envios.last['tipo'], 'ConfirmarPedidoRede');
    final salvo =
        jsonDecode((await banco.ler(PedidosNaRede.chave(alvo, id)))!) as Map;
    expect(salvo['etapaDelivery'], 'preparando');
    await rede.receber(resposta); // ACK antigo de Aguardando nao regride Preparo.
    expect(jsonDecode((await banco.ler(PedidosNaRede.chave(alvo, id)))!)['etapaDelivery'], 'preparando');
    expect((await banco.db.query('operacoes', where: 'id = ?', whereArgs: [id])).single['estado'], 'concluido');
    final quantidade = socket.envios.length;
    await rede.prepararDelivery('delivery-local:$id');
    expect(socket.envios, hasLength(quantidade));
  });
}
