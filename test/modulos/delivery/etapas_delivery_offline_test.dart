import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/etapas_delivery_offline.dart';
import 'package:app/src/modulos/delivery/servicos/cancelamentos_delivery_offline.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../essencial/sincronizacao/sincronizacao_test.dart'
    show SocketOfflineTeste;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory pasta;
  late BancoLocal banco;
  late EtapasDeliveryOffline etapas;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late SocketOfflineTeste socket;
  late Sincronizador sync;
  late ServicoDelivery servico;
  var conectado = false;
  var perderResposta = false;
  var recusarEtapa = false;
  var apiSemEtapas = false;
  final envios = <Map<String, dynamic>>[];
  final aplicados = <String>{};

  EtapaDelivery etapa(String id, String impressao, {bool entregador = false}) =>
      EtapaDelivery.fromMap({
        'id': id,
        'nomeOpcao': id,
        'tipodeimpressao': impressao,
        'ativarselecaoentregador': entregador ? 'Sim' : 'Não',
      });
  final aguardando = etapa('10', '0');
  final preparo = etapa('20', '1');
  final transito = etapa('30', '2', entregador: true);
  final finalizado = etapa('40', '3');

  PedidoDelivery pedido(
          {String id = '77', Map<String, dynamic> campos = const {}}) =>
      PedidoDelivery.fromMap({
        'id': id,
        'numeroPedido': '0',
        'nomeCliente': 'Cliente',
        'idopcoescarrossel': '10',
        'status': 'Pendente',
        'tipodeentrega': '1',
        'valorVenda': '8.00',
        'somaValorHistorico': '8.00',
        'quantidadeprodutos': '1',
        'dataAbertura': DateTime.now().toIso8601String(),
        'produtos': [
          {'id': '1', 'nome': 'Almoço', 'valorVenda': '8', 'quantidade': 1}
        ],
        ...campos,
      });

  Future<PedidoDelivery> avancar(PedidoDelivery pedido, EtapaDelivery destino,
          {String entregador = '', List<String> impressoes = const []}) =>
      etapas.avancar(
          pedido: pedido,
          destino: destino,
          empresa: '32',
          usuario: '1',
          conexao: sync.destino,
          entregador: entregador,
          valorEntrega: '0',
          impressoes: impressoes);

  setUp(() async {
    conectado = false;
    perderResposta = false;
    recusarEtapa = false;
    apiSemEtapas = false;
    envios.clear();
    aplicados.clear();
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})
    });
    pasta = await Directory.systemTemp.createTemp('etapas-delivery-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    api = DioCliente();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32', nome: 'Garcom'));
    socket = SocketOfflineTeste();
    sync = Sincronizador(api, usuario, socket, banco: banco);
    Sincronizador.instancia = sync;
    await sync.configurar();
    etapas = EtapasDeliveryOffline(banco, sync.escopo);
    await etapas.prepararEtapas([aguardando, preparo, transito, finalizado]);
    servico = ServicoDelivery(api, usuario);
    api.cliente.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) {
      final rota = CacheConsultas.caminho(options);
      if (options.method != 'POST' || rota != 'sincronizacao/operacao.php') {
        handler.resolve(Response(requestOptions: options, data: []));
        return;
      }
      final entrada =
          Map<String, dynamic>.from(jsonDecode(options.data as String) as Map);
      envios.add(entrada);
      if (!conectado) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
        return;
      }
      if (recusarEtapa && entrada['acao'] == 'etapa_delivery') {
        handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 409, data: {
              'protocolo': 1,
              'sucesso': false,
              'codigo': 'atendimento_alterado',
              'mensagem': 'Pedido mudou.'
            })));
        return;
      }
      if (apiSemEtapas && entrada['acao'] == 'etapa_delivery') {
        handler.reject(DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response(requestOptions: options, statusCode: 422, data: {
              'protocolo': 1,
              'sucesso': false,
              'codigo': 'sincronizacao_indisponivel',
              'mensagem': 'Operacao invalida.',
            })));
        return;
      }
      aplicados.add(entrada['id_operacao'] as String);
      if (perderResposta) {
        perderResposta = false;
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.receiveTimeout));
        return;
      }
      handler.resolve(Response(requestOptions: options, data: {
        'protocolo': 1,
        'sucesso': true,
        'id_operacao': entrada['id_operacao'],
        'idDelivery': entrada['dados']['id'],
        'status': entrada['dados']['status'],
        'etapaConfirmada': true,
        if (entrada['dados']['concluir'] == true) 'idVenda': '90',
      }));
    }));
  });

  tearDown(() async {
    await sync.enviarPendentes();
    sync.dispose();
    Sincronizador.instancia = null;
    socket.dispose();
    usuario.dispose();
    api.cliente.close(force: true);
    BancoLocal.instancia = null;
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  test(
      'preparo e trânsito duráveis funcionam antes do primeiro HTTP e do reinício',
      () async {
    final inicial = pedido();
    final preparado = await avancar(inicial, preparo);
    final emTransito = await avancar(preparado, transito, entregador: '5');
    expect(envios, isEmpty);
    expect(emTransito.etapa, '30');
    final reaberto = EtapasDeliveryOffline(banco, sync.escopo);
    expect((await reaberto.projetar(inicial)).etapa, '30');
    final quadro = await reaberto.projetarQuadro([
      EtapaDelivery.comPedidos(aguardando, [inicial]),
      preparo,
      transito,
    ]);
    expect(quadro.first.pedidos, isEmpty);
    expect(quadro.last.pedidos.single.id, inicial.id);
    expect(await banco.operacoes(sync.escopo), hasLength(2));
  });

  test(
      'duplo clique usa o mesmo recibo e retrato atrasado não cria outro avanço',
      () async {
    final inicial = pedido();
    final a = await avancar(inicial, preparo);
    final b = await avancar(inicial, preparo);
    expect(a.texto('idOperacaoEtapaLocal'), b.texto('idOperacaoEtapaLocal'));
    await expectLater(
        avancar(inicial, transito, entregador: '5'), throwsStateError);
    expect(await banco.operacoes(sync.escopo), hasLength(1));
  });

  test('mantém regras de MP, cancelamento, entregador e saldo', () async {
    await expectLater(
        avancar(
            pedido(campos: {
              'pagamento_online_obrigatorio': true,
              'pagamento_online_tipo': '5',
              'pagamento_online_status': 'pending',
            }),
            preparo),
        throwsStateError);
    await expectLater(avancar(pedido(campos: {'status': 'Cancelado'}), preparo),
        throwsStateError);
    await expectLater(avancar(pedido(), transito), throwsStateError);
    await expectLater(
        avancar(pedido(campos: {'somaValorHistorico': '2'}), finalizado),
        throwsStateError);
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test('envio perdido conserva o recibo, payload e ordem dos próximos avanços',
      () async {
    final preparado = await avancar(pedido(), preparo);
    await avancar(preparado, transito, entregador: '5');
    conectado = true;
    perderResposta = true;
    await sync.enviarPendentes();
    expect(envios, hasLength(1));
    final primeiro = envios.single;
    await sync.retomarEnvios();
    expect(envios, hasLength(3));
    expect(envios[1], primeiro);
    expect(envios.map((e) => e['dados']['status']), ['20', '20', '30']);
    expect(aplicados, hasLength(2));
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test(
      'serviço libera cozinha e etapa sem esperar API nem confirmação da impressora',
      () async {
    final impressao = jsonEncode({
      'idRequisicao': 'preparo-unico',
      'tipoImpressao': '1',
      'numeroPedido': '',
      'comanda': 'Delivery 77',
    });
    socket.processamento = Completer<void>();
    final resultado = await servico.avancar(pedido(), preparo,
        impressoes: [impressao]).timeout(const Duration(seconds: 1));
    expect(resultado['sucesso'], true);
    expect(resultado['impressoes_enfileiradas'], true);
    expect(socket.filaImpressao.itens.single.id, 'preparo-unico');
    final operacao = (await banco.operacoes(sync.escopo)).single;
    final dados = jsonDecode(operacao['dados'] as String) as Map;
    expect(dados['impressao_local'], true);
    await sync.registrarImpressaoEtapaDelivery(operacao['id'] as String);
    expect(socket.filaImpressao.itens, hasLength(1));
    socket.processamento!.complete();
  });

  test('criação local confirmada sem número libera os avanços com ID real',
      () async {
    const id = 'delivery-local:origem';
    await banco.db.insert('operacoes', {
      'id': 'origem',
      'escopo': sync.escopo,
      'atendimento': id,
      'acao': 'delivery',
      'estado': 'concluido',
      'dados': jsonEncode({
        'empresa': '32',
        'id_usuario': '1',
        'produtos': [],
      }),
      'impressoes': '[]',
      'destino': sync.destino,
      'criado': 1,
      'resposta': jsonEncode({'idDelivery': '101', 'numeroPedido': '0'}),
    });
    await avancar(
        pedido(id: id, campos: {'faseLocal': 'enfileirado'}), preparo);
    conectado = true;
    await sync.enviarPendentes();
    expect(envios.single['dados']['id'], '101');
    expect(envios.single['dados']['statusOrigem'], '10');
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test('projeção conserva pagamento novo e não libera MP revogado ou cancelado',
      () async {
    await avancar(pedido(), preparo);
    final recebido = pedido(campos: {
      'valorVenda': '12.00',
      'somaValorHistorico': '12.00',
    });
    final projetado = await etapas.projetar(recebido);
    expect(projetado.etapa, '20');
    expect(projetado.total, 12);
    expect(projetado.pago, 12);
    final cancelado =
        await etapas.projetar(pedido(campos: {'status': 'Cancelado'}));
    expect(cancelado.cancelado, true);
    expect(cancelado.etapa, '10');
    final mp = await etapas.projetar(pedido(campos: {
      'pagamento_online_obrigatorio': true,
      'pagamento_online_tipo': '5',
      'pagamento_online_status': 'refunded',
      'pagamento_online_liberado': false,
    }));
    expect(mp.aguardandoPagamentoOnline, true);
    expect(mp.etapa, '10');
  });

  test('filtro não recoloca pedidos de outro período e modalidade', () async {
    await avancar(pedido(), preparo);
    final quadro = await etapas.projetarQuadro([aguardando, preparo, transito],
        filtro: (p) => p.tipoEntrega == '2');
    expect(quadro.expand((e) => e.pedidos), isEmpty);
    final outroPeriodo = await etapas.projetarQuadro([aguardando, preparo],
        filtro: (p) => p.abertura!.isBefore(DateTime(2000)));
    expect(outroPeriodo.expand((e) => e.pedidos), isEmpty);
  });

  test('retirada não exige entregador; pendência financeira exige quitar final',
      () async {
    final retirada =
        pedido(campos: {'tipodeentrega': '2', 'idopcoescarrossel': '20'});
    final emTransito = await avancar(retirada, transito);
    expect(emTransito.etapa, '30');
    final pendente = pedido(id: '88', campos: {
      'idopcoescarrossel': '30',
      'pagamentoPendente': true,
      'somaValorHistorico': '0',
    });
    await expectLater(avancar(pendente, finalizado), throwsStateError);
  });

  test('etapa já confirmada não impede avanço feito depois em outro aparelho',
      () async {
    final preparado = await avancar(pedido(), preparo);
    await banco.atualizarOperacao(
        preparado.texto('idOperacaoEtapaLocal'), {'estado': 'concluido'});
    final atualRemoto = pedido(campos: {'idopcoescarrossel': '30'});
    final concluido = await avancar(atualRemoto, finalizado);
    expect(concluido.etapa, '40');
    final op = (await banco.operacoes(sync.escopo)).single;
    expect((jsonDecode(op['dados'] as String) as Map)['concluir'], true);
  });

  test('ordem de etapas e regra preparada de pagamento permanecem locais',
      () async {
    await expectLater(
        avancar(pedido(), transito, entregador: '5'), throwsStateError);
    await etapas.prepararConfig(const ConfigDelivery(receberNoFinal: false));
    final parcial = pedido(campos: {'somaValorHistorico': '4.00'});
    await expectLater(avancar(parcial, preparo), throwsStateError);
    await etapas.prepararConfig(const ConfigDelivery(receberNoFinal: true));
    expect((await avancar(parcial, preparo)).etapa, '20');
  });

  test('entregadores preparados abrem e pesquisam sem aguardar HTTP lento',
      () async {
    final opcoes = RequestOptions(
        path: 'entregador/listar_por_nome.php',
        baseUrl: sync.servidor,
        queryParameters: {
          'empresa': '32',
          'id_usuario': '1',
          'cliente': '0',
          'pesquisa': ''
        });
    await banco.guardarConsulta(sync.escopo, CacheConsultas.chave(opcoes), [
      {'id': '5', 'nomecompleto': 'Ana Motorista', 'telefone': '123'},
      {'id': '6', 'nomecompleto': 'Bruno Motorista', 'telefone': '456'},
    ]);
    final bloqueio = Completer<void>();
    api.cliente.interceptors.insert(3,
        InterceptorsWrapper(onRequest: (options, handler) async {
      if (CacheConsultas.caminho(options) != 'entregador/listar_por_nome.php') {
        handler.next(options);
        return;
      }
      await bloqueio.future;
      handler.resolve(Response(requestOptions: options, data: []));
    }));
    try {
      final lista =
          await servico.entregadores().timeout(const Duration(seconds: 1));
      expect(lista, hasLength(2));
      final busca =
          await servico.entregadores('ana').timeout(const Duration(seconds: 1));
      expect(busca.single['id'], '5');
    } finally {
      bloqueio.complete();
      await Future<void>.delayed(Duration.zero);
    }
  });

  test('MP ausente da lista oficial não é ressuscitado por intenção antiga',
      () async {
    final aprovado = pedido(campos: {
      'pagamento_online_obrigatorio': true,
      'pagamento_online_tipo': '5',
      'pagamento_online_status': 'approved',
      'pagamento_online_liberado': true,
    });
    await avancar(aprovado, preparo);
    final quadro = await etapas.projetarQuadro([aguardando, preparo]);
    expect(quadro.expand((e) => e.pedidos), isEmpty);
  });

  test(
      'conflito de etapa cancela as impressões ainda pendentes sem reenfileirar',
      () async {
    final preparado = await avancar(pedido(), preparo, impressoes: [
      jsonEncode({
        'idRequisicao': 'preparo-em-conflito',
        'tipoImpressao': '1',
      })
    ]);
    await sync.registrarImpressaoEtapaDelivery(
        preparado.texto('idOperacaoEtapaLocal'));
    conectado = true;
    recusarEtapa = true;
    await sync.enviarPendentes();
    expect((await banco.operacoes(sync.escopo)).single['estado'], 'conflito');
    expect(socket.filaImpressao.itens.single.estado,
        EstadoImpressao.cancelamentoPendente);
    await sync.registrarImpressaoEtapaDelivery(
        preparado.texto('idOperacaoEtapaLocal'));
    expect(socket.filaImpressao.itens.single.estado,
        EstadoImpressao.cancelamentoPendente);
  });

  test(
      'cancelamento operacional retira impressão agendada e bloqueia recuperação',
      () async {
    final preparado = await avancar(pedido(), preparo, impressoes: [
      jsonEncode({
        'idRequisicao': 'preparo-cancelado',
        'tipoImpressao': '1',
      })
    ]);
    final id = preparado.texto('idOperacaoEtapaLocal');
    await sync.registrarImpressaoEtapaDelivery(id);
    await CancelamentosDeliveryOffline(banco, sync.escopo).guardar(
        id: '77',
        empresa: '32',
        usuario: '1',
        senha: 'admin',
        motivo: '',
        etapa: '20',
        destino: sync.destino);
    await sync.cancelarImpressoesEtapasDelivery('77');
    await sync.registrarImpressaoEtapaDelivery(id);
    expect(socket.filaImpressao.itens.single.estado,
        EstadoImpressao.cancelamentoPendente);
    await expectLater(
        avancar(preparado, transito, entregador: '5'), throwsStateError);
  });

  test(
      'API antiga mantém etapas pendentes e permite continuar antes da atualização',
      () async {
    final preparado = await avancar(pedido(), preparo, impressoes: [
      jsonEncode({
        'idRequisicao': 'preparo-api-antiga',
        'tipoImpressao': '1',
      })
    ]);
    conectado = true;
    apiSemEtapas = true;
    await sync.enviarPendentes();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    expect(pendente['estado'], 'pendente');
    expect(pendente['proxima'] as int,
        greaterThan(DateTime.now().millisecondsSinceEpoch));
    expect(pendente['erro'], contains('Atualize a API'));
    expect(socket.filaImpressao.itens.single.estado,
        EstadoImpressao.aguardandoEnvio);
    final primeiroEnvio = envios.single;

    final emTransito = await avancar(preparado, transito, entregador: '5');
    expect(emTransito.etapa, '30');
    expect((await banco.operacoes(sync.escopo)).map((op) => op['estado']),
        ['pendente', 'pendente']);
    await sync.enviarPendentes();
    expect(envios, hasLength(1));

    apiSemEtapas = false;
    await sync.retomarEnvios();
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(envios.map((e) => e['dados']['status']), ['20', '20', '30']);
    expect(envios[1], primeiroEnvio);
    expect(aplicados, hasLength(2));
    expect(socket.filaImpressao.itens, hasLength(1));
    expect(socket.filaImpressao.itens.single.estado,
        EstadoImpressao.aguardandoEnvio);
  });
}
