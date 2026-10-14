import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/pedidos_na_rede.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/cancelamentos_delivery_offline.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../essencial/sincronizacao/sincronizacao_test.dart'
    show SocketOfflineTeste;
import 'delivery_test.dart' show pedidoTeste;
import 'pagamento_online_delivery_test.dart' show pedidoOnline;

class _ServicoPainel extends ServicoDelivery {
  _ServicoPainel(super.dio, super.usuario);
  PedidoDelivery atual = pedidoTeste();
  Completer<List<EtapaDelivery>>? listaPausada;
  int consultasDetalhe = 0;
  final cancelamentos = <String>{};

  @override
  Future<Set<String>> pedidosComCancelamentoLocal() async => cancelamentos;

  @override
  Future<Map<String, dynamic>> acao(String acao, PedidoDelivery pedido,
      [Map<String, dynamic> campos = const {}]) async {
    final resposta = await super.acao(acao, pedido, campos);
    if (acao == 'cancelar') cancelamentos.add(pedido.id);
    return resposta;
  }

  @override
  Future<ConfigDelivery> configuracao() async =>
      const ConfigDelivery(motivoCancelamentoObrigatorio: true);

  @override
  Future<PedidoDelivery> pedido(String id) async {
    consultasDetalhe++;
    throw StateError('Detalhe remoto nao disponivel offline.');
  }

  @override
  Future<List<EtapaDelivery>> listar(
          {required DateTime inicio,
          required DateTime fim,
          required String horaInicio,
          required String horaFim,
          String pesquisa = '',
          String tipo = '0'}) async =>
      listaPausada == null ? [_etapa(atual)] : await listaPausada!.future;
}

EtapaDelivery _etapa(PedidoDelivery pedido) => EtapaDelivery.fromMap({
      'id': '1',
      'nomeOpcao': 'Aguardando',
      'nomeBotao': 'Preparar',
      'tipodeimpressao': '0',
      'vendas': [pedido.dados],
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory pasta;
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late SocketOfflineTeste socket;
  late Sincronizador sync;
  late ServicoDelivery servico;
  late CancelamentosDeliveryOffline fila;
  var conectado = false;
  var senhaValida = true;
  var perderResposta = false;
  var reciboIncompleto = false;
  final chamadas = <Map<String, dynamic>>[];
  final aplicados = <String>{};

  setUp(() async {
    conectado = false;
    senhaValida = true;
    perderResposta = false;
    reciboIncompleto = false;
    chamadas.clear();
    aplicados.clear();
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'local',
        'servidor': 'cozinha',
        'porta': '9980',
      })
    });
    pasta = await Directory.systemTemp.createTemp('delivery-cancelar-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    api = DioCliente();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32'));
    socket = SocketOfflineTeste();
    sync = Sincronizador(api, usuario, socket, banco: banco);
    Sincronizador.instancia = sync;
    await sync.configurar();
    fila = CancelamentosDeliveryOffline(banco, sync.escopo);
    servico = ServicoDelivery(api, usuario);
    api.cliente.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      final rota = CacheConsultas.caminho(o);
      if (o.method == 'POST') {
        final dados = Map<String, dynamic>.from(jsonDecode(o.data as String));
        chamadas.add(dados);
        expect(rota, 'sincronizacao/operacao.php');
        expect(dados['acao'], 'cancelar_delivery');
        expect(dados['impressoes'], isEmpty);
        expect((dados['dados'] as Map).containsKey('senha'), isFalse);
        if (!conectado) {
          h.reject(DioException(
              requestOptions: o, type: DioExceptionType.connectionError));
          return;
        }
        if (!senhaValida) {
          h.reject(DioException(
              requestOptions: o,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: o, statusCode: 422, data: {
                'protocolo': 1,
                'sucesso': false,
                'codigo': 'cancelamento_nao_autorizado',
                'mensagem': 'Senha Admin de cancelamento incorreta.',
              })));
          return;
        }
        final id = dados['id_operacao'] as String;
        aplicados.add(id);
        if (perderResposta) {
          perderResposta = false;
          h.reject(DioException(
              requestOptions: o, type: DioExceptionType.receiveTimeout));
          return;
        }
        h.resolve(Response(requestOptions: o, statusCode: 200, data: {
          'protocolo': 1,
          'id_operacao': id,
          'sucesso': true,
          'idDelivery': (dados['dados'] as Map)['id'],
          'status': 'Cancelado',
          if (!reciboIncompleto) 'cancelamento_operacional': true,
        }));
        return;
      }
      if (rota == 'delivery/listar_opcoes.php') {
        h.resolve(Response(requestOptions: o, statusCode: 200, data: {
          'sucesso': true,
          'dados': [
            {
              'id': '1',
              'vendas': [
                pedidoOnline(
                    status: 'approved',
                    liberado: true,
                    campos: {'somaValorHistorico': '86.00'}).dados,
                pedidoTeste(campos: {'id': '26'}).dados
              ],
            }
          ]
        }));
      } else if (rota == 'delivery/listar_opcoes_por_id.php') {
        h.resolve(Response(requestOptions: o, statusCode: 200, data: {
          'sucesso': true,
          'dados': pedidoOnline(status: 'approved', liberado: true).dados
        }));
      } else {
        h.reject(DioException(
            requestOptions: o, type: DioExceptionType.connectionError));
      }
    }));
  });

  tearDown(() async {
    sync.dispose();
    api.cliente.close(force: true);
    usuario.dispose();
    socket.dispose();
    BancoLocal.instancia = null;
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  Future<Map<String, dynamic>> cancelar(PedidoDelivery pedido,
          {String senha = 'senha-apenas-teste'}) =>
      servico.acao('cancelar', pedido,
          {'senha': senha, 'motivo': 'Solicitado pelo cliente'});

  for (final tipo in ['5', '6']) {
    for (final status in ['pending', 'approved', 'refunded']) {
      test('MP $tipo $status permite cancelamento offline sem mexer financeiro',
          () async {
        final pedido = pedidoOnline(
            tipo: tipo,
            status: status,
            liberado: status == 'approved',
            campos: {'somaValorHistorico': '86.00'});
        final original = jsonEncode(pedido.dados);
        final resposta = await cancelar(pedido);
        expect(resposta['sucesso'], isTrue);
        expect(resposta['salvo_no_aparelho'], isTrue);
        final op = (await banco.operacoes(sync.escopo)).single;
        expect(op['acao'], 'cancelar_delivery');
        expect(op['estado'], 'pendente');
        expect(op['impressoes'], '[]');
        expect(op['dados'].toString(), isNot(contains('senha-apenas-teste')));
        final dados = jsonDecode(op['dados'] as String) as Map;
        final esperado = Hmac(sha256, utf8.encode('senha-apenas-teste'))
            .convert(utf8.encode(jsonEncode([
              'cancelar_delivery',
              op['id'],
              '32',
              '1',
              '25',
            ])))
            .toString();
        expect(dados['autorizacao_cancelamento'], esperado);
        expect(jsonEncode(pedido.dados), original);
        expect(await fila.pedidosOcultos(), {'25'});
        expect(socket.recuperacoes, isEmpty);
        expect(socket.filaImpressao.itens, isEmpty);
        expect(chamadas.every((c) => c['acao'] == 'cancelar_delivery'), isTrue);
      });
    }
  }

  test('pedido comum usa o mesmo cancelamento mantendo os pagamentos',
      () async {
    final p = pedidoTeste(campos: {'somaValorHistorico': '20.00'});
    await cancelar(p);
    expect(p.pago, 20);
    expect(await fila.pedidosOcultos(), {'25'});
  });

  test('cliques concorrentes e reinicio conservam unico UUID e tombstone',
      () async {
    final respostas = await Future.wait([
      cancelar(pedidoOnline()),
      cancelar(pedidoOnline()),
      cancelar(pedidoOnline())
    ]);
    expect(respostas.map((r) => r['id_operacao']).toSet(), hasLength(1));
    expect(await banco.operacoes(sync.escopo), hasLength(1));
    await banco.db.close();
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    fila = CancelamentosDeliveryOffline(banco, sync.escopo);
    expect(await fila.pedidosOcultos(), {'25'});
    expect(
        await CancelamentosDeliveryOffline(
                banco, BancoLocal.escopo(sync.servidor, '99', '1'))
            .pedidosOcultos(),
        isEmpty);
  });

  test('cache/listagem e detalhe antigos nao ressuscitam pedido cancelado',
      () async {
    await cancelar(pedidoOnline(status: 'approved', liberado: true));
    final lista = await servico.listar(
        inicio: DateTime.now(),
        fim: DateTime.now(),
        horaInicio: '05:00:00',
        horaFim: '05:00:00');
    expect(lista.single.pedidos.map((p) => p.id), ['26']);
    expect((await servico.pedido('25')).cancelado, isTrue);
    await expectLater(
        servico.avancar(
            pedidoOnline(status: 'approved', liberado: true), lista.single),
        throwsStateError);
    await expectLater(
        ImpressaoDelivery.prepararMensagens(
            servico, pedidoOnline(status: 'approved', liberado: true)),
        throwsStateError);
  });

  test('resposta perdida repete o mesmo cancelamento sem impressao', () async {
    conectado = true;
    perderResposta = true;
    final resposta =
        await cancelar(pedidoOnline(status: 'approved', liberado: true));
    final id = resposta['id_operacao'] as String;
    final primeiro = jsonEncode(chamadas.single);
    await banco.atualizarOperacao(id, {'proxima': 0});
    await sync.enviarPendentes();
    expect(jsonEncode(chamadas.last), primeiro);
    expect(aplicados, {id});
    expect((await fila.operacao(id))?['estado'], 'concluido');
    expect(await fila.pedidosOcultos(), {'25'});
    expect(socket.recuperacoes, isEmpty);
    expect(
        socket.mensagens.where((m) => m['tipo'] == 'Delivery'), hasLength(1));
  });

  test('cancelamento precede itens pendentes e impede preparo antigo pela LAN',
      () async {
    final operacaoAntiga = BancoLocal.novoId();
    await banco.db.insert('operacoes', {
      'id': operacaoAntiga,
      'escopo': sync.escopo,
      'atendimento': '25',
      'acao': 'produtos',
      'estado': 'pendente',
      'criado': 1,
      'dados': jsonEncode({
        'empresa': '32',
        'id_usuario': '1',
        'tipo': 'delivery',
        'produtos': []
      }),
      'impressoes': '[]',
      'destino': sync.destino,
    });
    final operacaoLocal = BancoLocal.novoId();
    await banco.db.insert('operacoes', {
      'id': operacaoLocal,
      'escopo': sync.escopo,
      'atendimento': 'delivery-local:$operacaoLocal',
      'acao': 'delivery',
      'estado': 'concluido',
      'criado': 1,
      'dados': jsonEncode({'empresa': '32', 'id_usuario': '1'}),
      'resposta': jsonEncode({'idDelivery': '25'}),
      'impressoes': '[]',
      'destino': sync.destino,
    });
    const executor = 'preparo-11111111111111111111111111111111';
    await banco.gravar(
        PedidosNaRede.chave(sync.escopo, operacaoLocal),
        jsonEncode({
          'id': operacaoLocal,
          'executor': executor,
          'escopo': socket.escopoPedidosRede,
          'recebido': true,
          'preparoSolicitado': true,
          'mensagem': {
            'pedido': {'tipoAtendimento': 'delivery'},
            'impressoes': []
          }
        }));
    await cancelar(pedidoOnline(status: 'approved', liberado: true));
    conectado = true;
    final cancelamento = (await banco.operacoes(sync.escopo))
        .singleWhere((op) => op['acao'] == 'cancelar_delivery');
    await banco.atualizarOperacao(cancelamento['id'] as String, {'proxima': 0});
    await sync.enviarPendentes();
    socket.connected = true;
    socket.executorPedidosRede = executor;
    final rede = PedidosNaRede(banco, socket, usuario)
      ..configurar(sync.escopo, socket.escopoPedidosRede);
    addTearDown(rede.dispose);
    await rede.processar();
    expect(chamadas.every((c) => c['acao'] == 'cancelar_delivery'), isTrue);
    expect(socket.pedidosRede, isEmpty);
    expect(socket.recuperacoes, isEmpty);
    expect((await banco.operacoes(sync.escopo)).single['id'], operacaoAntiga);
    expect((await banco.operacoes(sync.escopo)).single['estado'], 'pendente');
  });

  test('recibo incompleto permanece pendente sem declarar cancelamento remoto',
      () async {
    conectado = true;
    reciboIncompleto = true;
    final resposta = await cancelar(pedidoOnline());
    expect(resposta['salvo_no_aparelho'], isTrue);
    expect(
        (await fila.operacao(resposta['id_operacao']))?['estado'], 'pendente');
    expect(await fila.pedidosOcultos(), {'25'});
  });

  test('senha rejeitada restaura pedido e nova autorizacao nao fica bloqueada',
      () async {
    conectado = true;
    senhaValida = false;
    await expectLater(cancelar(pedidoOnline()), throwsStateError);
    expect(await fila.pedidosOcultos(), isEmpty);
    expect((await banco.operacoes(sync.escopo)).single['estado'], 'conflito');
    senhaValida = true;
    final autorizado = await cancelar(pedidoOnline(), senha: 'senha-corrigida');
    expect(autorizado['salvo_no_aparelho'], isFalse,
        reason: jsonEncode(await banco.operacoes(sync.escopo)));
    expect(await fila.pedidosOcultos(), {'25'});
    expect(aplicados, hasLength(1));
  });

  test(
      'notificacao de cancelamento invalida resposta em voo e retrato otimista',
      () async {
    final painel = _ServicoPainel(api, usuario)
      ..atual = pedidoOnline(status: 'approved', liberado: true);
    final provedor = ProvedorDelivery(painel);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.atualizarPedido(painel.atual);
    painel.listaPausada = Completer<List<EtapaDelivery>>();
    final leitura = provedor.listar(mostrarCarregamento: false);
    await Future<void>.delayed(Duration.zero);
    final cancelado = PedidoDelivery.fromMap({
      ...painel.atual.dados,
      'status': 'Cancelado',
      'cancelamentoLocal': true
    });
    provedor.atualizarPedido(cancelado);
    provedor.atualizarPedido(painel.atual);
    painel.listaPausada!.complete([_etapa(painel.atual)]);
    await leitura;
    expect(provedor.etapas.single.pedidos, isEmpty);
  });

  test('HMAC do Flutter coincide com fixture da API PHP', () {
    expect(
        Hmac(sha256, utf8.encode('admin-teste'))
            .convert(utf8.encode(jsonEncode([
              'cancelar_delivery',
              List.filled(48, 'a').join(),
              '32',
              '1',
              '25',
            ])))
            .toString(),
        '4d50575af803bab9e8e73e680907cc230598f9c3cef7d2dabb48601c84996362');
  });
}
