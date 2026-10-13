import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/pedidos_compartilhados.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comanda.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const url = 'https://bigchef.com.br/api41/';
const rede = 'online|bigchef.com.br|2';
const executor = 'preparo-11111111111111111111111111111111';
String id(int n) => n.toRadixString(16).padLeft(48, 'a');
Map<String, dynamic> registro(String tipo, int n, {String? atendimento}) => {
      'idOperacaoRede': id(n),
      'estado': 'recebido',
      'recebidoEm': '2026-10-13T15:16:00',
      'pedido': {
        'tipoAtendimento': tipo,
        'recurso': '1',
        if (atendimento != null) 'idAtendimento': atendimento,
        'identificacaoAtendimento': '1',
        'nomeCliente': 'Bruno',
        'tipodeentrega': '1',
        'produtos': [
          {
            'id': '5',
            'nome': 'Coca Cola 2L',
            'quantidade': 1,
            'valorVenda': '5.00'
          }
        ]
      }
    };
Map<String, dynamic> snapshot(List<Map<String, dynamic>> pedidos,
        [int revisao = 1]) =>
    {
      'tipo': 'PedidosCompartilhadosRede',
      'protocoloPedidoRede': 1,
      'idEmpresa': '2',
      'executorImpressaoRede': executor,
      'sessaoRede': id(9),
      'revisao': revisao,
      'pedidos': pedidos
    };
List<Map<String, dynamic>> grupos(
        [String tipo = 'comanda', String valor = '30']) =>
    [
      {
        'titulo': 'Ocupadas',
        '${tipo}s': [
          {
            'id': '1',
            'nome': '1',
            '${tipo}Ocupada': true,
            'idComandaPedido': '104',
            'nomeCliente': 'Bruno',
            'valor': valor
          }
        ]
      },
      {'titulo': 'Livres', '${tipo}s': []}
    ];

class Transporte implements HttpClientAdapter {
  bool online = false;
  int chamadas = 0;
  Object dados = grupos();
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas++;
    if (!online) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(jsonEncode(dados), 200, headers: {
      Headers.contentTypeHeader: ['application/json']
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  late Directory pasta;
  late Dio dio;
  late CacheConsultas cache;
  late Transporte transporte;
  late String alvo;
  setUp(() async {
    pasta = await Directory.systemTemp.createTemp('consulta-rede-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/teste.db');
    alvo = BancoLocal.escopo(url, '2', '311');
    dio = Dio(BaseOptions(baseUrl: url));
    transporte = Transporte();
    dio.httpClientAdapter = transporte;
    cache = CacheConsultas(dio, banco)
      ..escopo = alvo
      ..servidor = url
      ..empresa = '2';
    cache.pedidosRede.configurar(alvo, rede, executor);
    dio.interceptors.add(cache);
  });
  tearDown(() async {
    dio.close(force: true);
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  test(
      'Wi-Fi atualiza quatro modulos sem internet e nao cria outra fila de envio',
      () async {
    await cache.pedidosRede.receber(snapshot([
      registro('comanda', 1, atendimento: '104'),
      registro('mesa', 2, atendimento: '105'),
      registro('delivery', 3),
      registro('balcao', 4)
    ]));
    final op = RequestOptions(
        path: 'comandas/listar.php',
        baseUrl: url,
        queryParameters: {'empresa': '2', 'pesquisa': ''});
    await banco.guardarConsulta(alvo, CacheConsultas.chave(op), grupos());
    final comandas = await dio.get('comandas/listar.php',
        queryParameters: op.queryParameters);
    expect(comandas.data.first['comandas'].single['valor'], '35.00');
    final mesas =
        await dio.get('mesas/listar.php', queryParameters: {'empresa': '2'});
    expect(mesas.data.first['mesas'].single['mesaOcupada'], true);
    expect(
        mesas.data.first['mesas'].single['idComandaPedido'], 'rede:${id(2)}');
    expect(MesaModelo.fromMap(mesas.data.first['mesas'].single).valor, '5.00');
    final delivery = await dio
        .get('delivery/listar_opcoes.php', queryParameters: {'empresa': '2'});
    final etapas = (delivery.data['dados'] as List)
        .map((e) => EtapaDelivery.fromMap(e))
        .toList();
    expect(etapas.single.pedidos.single.id, 'rede:${id(3)}');
    expect(etapas.single.pedidos.single.total, 5);
    final balcao = await dio.post('balcao/listar.php',
        queryParameters: {'id_empresa': '2', 'pagina': 1});
    expect(ModeloVendasBalcao.fromMap(balcao.data.single).valorTotalF, '5.00');
    expect(await banco.operacoes(alvo), isEmpty);
  });

  test(
      'detalhe Wi-Fi e consultavel e nunca permite receber ou alterar ID temporario',
      () async {
    await cache.pedidosRede.receber(snapshot([registro('delivery', 3)]));
    final detalhe = await dio.get('delivery/listar_opcoes_por_id.php',
        queryParameters: {'id': 'rede:${id(3)}', 'empresa': '2'},
        options: Options(extra: {'semCache': true}));
    expect(detalhe.data['dados']['produtos'].single['nome'], 'Coca Cola 2L');
    expect(transporte.chamadas, 0);
    await expectLater(
        dio.post('delivery/pagar_pedido.php',
            data: jsonEncode({'id': 'rede:${id(3)}'})),
        throwsA(isA<DioException>()));
    expect(transporte.chamadas, 0);
    expect(await banco.operacoes(alvo), isEmpty);
  });

  test('snapshot repetido ou atrasado nao duplica e confirmacao remove a copia',
      () async {
    expect(
        await cache.pedidosRede
            .receber(snapshot([registro('comanda', 1, atendimento: '104')], 2)),
        true);
    expect(await cache.pedidosRede.receber(snapshot([], 1)), false);
    expect(await cache.pedidosRede.receber(snapshot([], 2)), false);
    for (var n = 0; n < 2; n++) {
      final r = await cache.pedidosRede.projetar(
          RequestOptions(path: 'comandas/listar.php'), grupos()) as List;
      expect(r.first['comandas'].single['valor'], '35.00');
    }
    await cache.pedidosRede.receber(snapshot([], 3));
    final oficial = grupos('comanda', '35');
    expect(
        await cache.pedidosRede
            .projetar(RequestOptions(path: 'comandas/listar.php'), oficial),
        oficial);
  });

  test('consulta persiste apos reinicio e isola conta, empresa e outro PC',
      () async {
    await cache.pedidosRede.receber(snapshot([registro('delivery', 3)]));
    final reaberto = PedidosCompartilhados(banco)
      ..configurar(alvo, rede, executor);
    expect(await reaberto.pedidos(), hasLength(1));
    expect(
        await reaberto
            .receber({...snapshot([]), 'idEmpresa': '3', 'revisao': 99}),
        false);
    reaberto.configurar(alvo, rede, 'preparo-22222222222222222222222222222222');
    expect(await reaberto.pedidos(), isEmpty);
    reaberto.configurar(BancoLocal.escopo(url, '2', '312'), rede, executor);
    expect(await reaberto.pedidos(), isEmpty);
    reaberto.configurar(alvo, null, null);
    expect(await reaberto.pedidos(), isEmpty);
  });

  test('aparelho de origem soma seus itens uma vez em comanda ja aberta',
      () async {
    final r = registro('comanda', 1, atendimento: '104');
    await cache.pedidosRede.receber(snapshot([r]));
    await banco.db.insert('operacoes', {
      'id': id(1),
      'escopo': alvo,
      'atendimento': '104',
      'acao': 'produtos',
      'estado': 'pendente',
      'dados':
          jsonEncode({'tipo': 'comanda', 'produtos': r['pedido']['produtos']}),
      'impressoes': '[]',
      'destino': '',
      'criado': 1
    });
    final base = await cache.pedidosRede.projetar(
        RequestOptions(path: 'comandas/listar.php'), grupos()) as List;
    final projetado = await AtendimentosLocais(banco, alvo)
        .projetarLista(base, 'comanda', '');
    expect(projetado.first['comandas'].single['valor'], '35.00');
    await banco.atualizarOperacao(id(1), {'estado': 'registrado'});
    final confirmado = await AtendimentosLocais(banco, alvo)
        .projetarLista(grupos('comanda', '35'), 'comanda', '');
    expect(confirmado.first['comandas'].single['valor'], '35');
  });

  test('atendimento confirmado com pedido Wi-Fi pendente bloqueia recebimento',
      () async {
    await cache.pedidosRede
        .receber(snapshot([registro('comanda', 1, atendimento: '104')]));
    await expectLater(
        AtendimentosLocais(banco, alvo).idServidorParaRecebimento('104'),
        throwsStateError);
  });

  test(
      'nova comanda com varios pedidos Wi-Fi ocupa uma vaga e mostra todos os itens',
      () async {
    await cache.pedidosRede.receber(snapshot([
      registro('comanda', 1, atendimento: 'local:abertura'),
      registro('comanda', 2, atendimento: 'local:abertura'),
    ]));
    final lista = await cache.pedidosRede
        .projetar(RequestOptions(path: 'comandas/listar.php'), []) as List;
    final comanda = ModeloComanda.fromMap(lista.first['comandas'].single);
    expect(comanda.valor, '10.00');
    final detalhe = await cache.pedidosRede.projetar(
        RequestOptions(
            path: 'cardapio/listar_por_id.php',
            queryParameters: {'id': comanda.idComandaPedido}),
        null) as Map;
    expect(detalhe['produtos'], hasLength(2));
    expect(detalhe['valorTotal'], '10.00');
    expect(detalhe['idComanda'], '1');
  });

  test('total completo do PC nao duplica pedido Delivery oficial', () async {
    final p = registro('delivery', 1, atendimento: '104');
    p['totalCompleto'] = true;
    p['pedido']['valorTotal'] = '35.00';
    await cache.pedidosRede.receber(snapshot([p]));
    final r = await cache.pedidosRede
        .projetar(RequestOptions(path: 'delivery/listar_opcoes.php'), {
      'sucesso': true,
      'dados': [
        {
          'id': '1',
          'tipodeimpressao': '0',
          'vendas': [
            {'id': '104', 'valorVenda': '30'}
          ]
        }
      ]
    }) as Map;
    final pedido = (r['dados'] as List).single['vendas'] as List;
    expect(pedido, hasLength(1));
    expect(pedido.single['id'], '104');
    expect(pedido.single['valorVenda'], '35.00');
  });

  test('origem consulta itens pendentes no detalhe de uma comanda ja aberta',
      () async {
    final r = registro('comanda', 1, atendimento: '104');
    await banco.db.insert('operacoes', {
      'id': id(1),
      'escopo': alvo,
      'atendimento': '104',
      'acao': 'produtos',
      'estado': 'pendente',
      'dados':
          jsonEncode({'tipo': 'comanda', 'produtos': r['pedido']['produtos']}),
      'impressoes': '[]',
      'destino': '',
      'criado': 1
    });
    final projetado = await AtendimentosLocais(banco, alvo).projetarDetalhe({
      'id': '104',
      'valorTotal': '30.00',
      'produtos': [
        {'nome': 'Itens anteriores'}
      ]
    }, 'comanda');
    expect(projetado['valorTotal'], '35.00');
    expect(projetado['produtos'], hasLength(2));
  });

  test(
      'copia antiga sem ID do atendimento bloqueia somente a conta do mesmo cadastro',
      () async {
    await cache.pedidosRede.receber(snapshot([registro('comanda', 1)]));
    final op = RequestOptions(
        path: 'comandas/listar.php', queryParameters: {'empresa': '2'});
    await banco.guardarConsulta(alvo, CacheConsultas.chave(op), grupos());
    expect(await cache.pedidosRede.temPendencia('104'), true);
    expect(await cache.pedidosRede.temPendencia('105'), false);
  });

  test('preparacao salva a consulta oficial sem incorporar itens da LAN',
      () async {
    await cache.pedidosRede
        .receber(snapshot([registro('comanda', 1, atendimento: '104')]));
    transporte.online = true;
    final resposta = await dio.get('comandas/listar.php',
        queryParameters: {'empresa': '2'},
        options: Options(extra: {'semCache': true, 'preparacaoOffline': true}));
    expect(resposta.data.first['comandas'].single['valor'], '30');
    final tela =
        await dio.get('comandas/listar.php', queryParameters: {'empresa': '2'});
    expect(tela.data.first['comandas'].single['valor'], '35.00');
    final consulta =
        await banco.consulta(alvo, CacheConsultas.chave(tela.requestOptions));
    expect(
        jsonDecode(consulta!['valor'] as String)
            .first['comandas']
            .single['valor'],
        '30');
  });
}
