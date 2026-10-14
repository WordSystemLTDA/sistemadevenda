import 'dart:convert';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/etapas_delivery_rede.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delivery_test.dart';
import 'pagamento_online_delivery_test.dart' show pedidoOnline;

class _ConsultaDelivery extends ServicoDelivery {
  _ConsultaDelivery()
      : super(
            DioFalso(),
            UsuarioProvedor()
              ..setUsuario(UsuarioModelo(id: '2', empresa: '3')));

  Map<String, dynamic> resposta = {};
  List<PedidoDelivery> locais = [];
  int consultas = 0;

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    expect(rota, 'delivery/listar_opcoes.php');
    consultas++;
    return resposta;
  }

  @override
  Future<List<PedidoDelivery>> pedidosLocais() async => locais;
}

EtapaDelivery _etapa(List<PedidoDelivery> pedidos) =>
    EtapaDelivery.comPedidos(etapasTeste().first, pedidos);

void main() {
  for (final tipo in ['5', '6']) {
    test('somente MP $tipo aprovado e liberado aparece no painel', () {
      for (final status in [
        '',
        'pending',
        'in_process',
        'authorized',
        'rejected',
        'cancelled',
        'refunded',
        'partially_refunded',
        'charged_back',
        'desconhecido',
      ]) {
        for (final liberado in [false, true]) {
          final pedido = pedidoOnline(
              tipo: tipo,
              status: status,
              liberado: liberado,
              campos: {'somaValorHistorico': '86.00'});
          expect(pedido.visivelNoPainelDelivery, isFalse,
              reason: '$status/$liberado');
        }
      }
      expect(
          pedidoOnline(tipo: tipo, status: 'approved').visivelNoPainelDelivery,
          isFalse);
      expect(
          pedidoOnline(tipo: tipo, status: ' APPROVED ', liberado: true)
              .visivelNoPainelDelivery,
          isTrue);
      expect(
          pedidoOnline(
              tipo: tipo,
              status: 'approved',
              liberado: true,
              campos: {'status': 'Cancelado'}).visivelNoPainelDelivery,
          isFalse);
    });
  }

  test('formas comuns e metadata incompleta fora dos tipos 5/6 permanecem', () {
    final pedidos = [
      pedidoTeste(),
      for (final tipo in ['', '1', '2', '3', '4', '7', 'desconhecido'])
        pedidoOnline(tipo: tipo),
      for (final tipo in ['5', '6'])
        pedidoOnline(
            tipo: tipo, campos: {'pagamento_online_obrigatorio': false}),
    ];
    expect(pedidos.every((pedido) => pedido.visivelNoPainelDelivery), isTrue);
    expect(_etapa(pedidos).pedidos, hasLength(pedidos.length));
  });

  test('a projecao filtra cache e copia sem alterar os registros originais',
      () {
    final pendente = pedidoOnline();
    final aprovado = pedidoOnline(
        tipo: '6', status: 'approved', liberado: true, campos: {'id': '26'});
    final comum = pedidoTeste(campos: {'id': '27'});
    final dados = {
      'id': '1',
      'vendas': [pendente.dados, aprovado.dados, comum.dados],
    };
    final original = jsonEncode(dados);
    final etapa = EtapaDelivery.fromMap(dados);
    expect(etapa.pedidos.map((pedido) => pedido.id), ['26', '27']);
    expect(
        _etapa([pendente, aprovado, comum]).pedidos.map((pedido) => pedido.id),
        ['26', '27']);
    expect(jsonEncode(dados), original);
    expect((dados['vendas']! as List), hasLength(3));
  });

  test('mescla Wi-Fi nao reintroduz MP pendente nem remove pedido comum', () {
    final comum = pedidoTeste(campos: {
      'id': 'delivery-local:comum',
      'faseLocal': 'enfileirado',
      'recebidoNaRede': true,
      'estadoSincronizacao': 'pendente',
    });
    final pendente = pedidoOnline(campos: {
      ...comum.dados,
      'id': 'delivery-local:mp',
      'pagamento_online_obrigatorio': true,
      'pagamento_online_tipo': '5',
    });
    final locais = [pendente, comum];
    final etapas = mesclarEtapasDeliveryRede([_etapa([])], locais);
    expect(etapas.single.pedidos.map((pedido) => pedido.id), [comum.id]);
    expect(locais, hasLength(2));
    final rascunho = PedidoDelivery.fromMap({
      ...pendente.dados,
      'faseLocal': 'rascunho',
      'recebidoNaRede': false,
    });
    expect(mesclarEtapasDeliveryRede([], [rascunho]), isEmpty);
  });

  test('listar conserva JSON em cache, oculta MP e mostra aprovacao posterior',
      () async {
    final servico = _ConsultaDelivery();
    servico.resposta = {
      'sucesso': true,
      'dados': [
        {
          'id': '1',
          'vendas': [pedidoOnline().dados]
        },
      ],
    };
    final cache = jsonEncode(servico.resposta);
    Future<List<EtapaDelivery>> listar() => servico.listar(
          inicio: DateTime.now(),
          fim: DateTime.now(),
          horaInicio: '05:00:00',
          horaFim: '05:00:00',
        );
    expect((await listar()).single.pedidos, isEmpty);
    expect(jsonEncode(servico.resposta), cache);
    servico.resposta = {
      'sucesso': true,
      'dados': [
        {
          'id': '1',
          'vendas': [pedidoOnline(status: 'approved', liberado: true).dados],
        },
      ],
    };
    expect((await listar()).single.pedidos.single.id, '25');
    expect(servico.consultas, 2);
  });

  test('copia Wi-Fi de MP nao substitui pedido aprovado oficial', () {
    final aprovado = pedidoOnline(status: 'approved', liberado: true);
    for (final status in ['pending', 'approved']) {
      final copia =
          pedidoOnline(status: status, liberado: status == 'approved', campos: {
        'id': 'delivery-local:mp',
        'idDeliveryConfirmado': aprovado.id,
        'faseLocal': 'enfileirado',
        'recebidoNaRede': true,
        'etapaDeliveryRede': 'preparando',
        'estadoSincronizacao': 'concluido',
      });
      final etapas = mesclarEtapasDeliveryRede([
        _etapa([aprovado])
      ], [
        copia
      ]);
      expect(etapas.single.pedidos.single.id, aprovado.id);
      expect(etapas.single.pedidos.single.aguardandoPagamentoOnline, isFalse);
    }
  });

  test('copia Wi-Fi antes aprovada nao ressuscita MP omitido pela API', () {
    final copia = pedidoOnline(status: 'approved', liberado: true, campos: {
      'id': 'delivery-local:mp',
      'idDeliveryConfirmado': '25',
      'faseLocal': 'enfileirado',
      'recebidoNaRede': true,
      'etapaDeliveryRede': 'preparando',
      'estadoSincronizacao': 'concluido',
    });
    expect(mesclarEtapasDeliveryRede([], [copia]), isEmpty);
    expect(mesclarEtapasDeliveryRede([_etapa([])], [copia]).single.pedidos,
        isEmpty);
    expect(copia.pagamentoOnlineStatus, 'approved');
  });

  test(
      'notificacao oculta pendente e revogado; aprovacao aparece imediatamente',
      () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [_etapa([])];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.atualizarPedido(pedidoOnline());
    expect(provedor.etapas.single.pedidos, isEmpty);
    provedor.atualizarPedido(pedidoOnline(status: 'approved', liberado: true));
    expect(provedor.etapas.single.pedidos.single.id, '25');
    provedor.atualizarPedido(pedidoOnline(status: 'refunded'));
    expect(provedor.etapas.single.pedidos, isEmpty);
  });

  test('omissao remota elimina retrato MP otimista e conserva pedido comum',
      () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [_etapa([])];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.atualizarPedido(pedidoOnline(status: 'approved', liberado: true));
    provedor.atualizarPedido(pedidoTeste(campos: {'id': '26'}));
    expect(provedor.etapas.single.pedidos, hasLength(2));
    await provedor.listar();
    expect(provedor.etapas.single.pedidos.single.id, '26');
  });

  test('notificacao da fila local nao cria MP sem resposta oficial', () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [_etapa([])];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.atualizarPedido(pedidoOnline(
        status: 'approved',
        liberado: true,
        campos: {'id': 'delivery-local:mp'}));
    expect(provedor.etapas.single.pedidos, isEmpty);
    provedor
        .atualizarPedido(pedidoTeste(campos: {'id': 'delivery-local:comum'}));
    expect(provedor.etapas.single.pedidos.single.id, 'delivery-local:comum');
  });

  test('resposta sem etapas nao conserva MP recentemente aprovado', () async {
    final servico = ServicoDeliveryTeste()
      ..respostaLista = () async => [_etapa([])];
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await provedor.listar();
    provedor.atualizarPedido(pedidoOnline(status: 'approved', liberado: true));
    servico.respostaLista = () async => [];
    await provedor.listar();
    expect(provedor.etapas, isEmpty);
    servico.respostaLista = () async => [_etapa([])];
    await provedor.listar();
    expect(provedor.etapas.single.pedidos, isEmpty);
  });
}
