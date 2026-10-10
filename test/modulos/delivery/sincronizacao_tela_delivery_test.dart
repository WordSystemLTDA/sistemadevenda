import 'dart:async';

import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delivery_test.dart';

class _Modulo extends Module {
  _Modulo(this.provedor);
  final ProvedorDelivery provedor;
  @override
  void binds(Injector i) => i.addInstance<ProvedorDelivery>(provedor);
}

class _ConfiguracaoLenta extends ServicoDeliveryTeste {
  final liberar = Completer<ConfigDelivery>();
  @override
  Future<ConfigDelivery> configuracao() => liberar.future;
}

void main() {
  test(
      'retorno da finalizacao mostra espera antes de iniciar consulta agrupada',
      () async {
    final servico = _ConfiguracaoLenta();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    final recebeuListaAntiga = Completer<void>();
    provedor.addListener(() {
      if (provedor.etapas.isNotEmpty && !recebeuListaAntiga.isCompleted) {
        recebeuListaAntiga.complete();
      }
    });
    final antiga = provedor.listar(mostrarCarregamento: false);
    await recebeuListaAntiga.future;
    final listaNova = Completer<List<EtapaDelivery>>();
    final iniciouConsultaNova = Completer<void>();
    servico.respostaLista = () {
      iniciouConsultaNova.complete();
      return listaNova.future;
    };
    final nova = provedor.listar();
    try {
      expect(provedor.carregando, true);
      expect(servico.consultas, 1);
      expect(provedor.etapas.first.pedidos, isNotEmpty);
      servico.liberar.complete(servico.config);
      await iniciouConsultaNova.future;
      expect(provedor.carregando, true);
    } finally {
      if (!servico.liberar.isCompleted) {
        servico.liberar.complete(servico.config);
      }
      listaNova.complete(etapasTeste());
      await Future.wait([antiga, nova]);
    }
    expect(provedor.carregando, false);
  });

  testWidgets(
      'Aguardando vazio mostra carregamento ate receber o pedido finalizado',
      (tester) async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    final emPreparo = pedidoTeste(
        campos: {'id': '7', 'numeroPedido': '7', 'idopcoescarrossel': '2'});
    List<EtapaDelivery> quadro({bool incluirLocal = true, bool novo = false}) =>
        [
          if (incluirLocal)
            EtapaDelivery.fromMap(
                {'id': 'local', 'nomeOpcao': 'No aparelho', 'vendas': []}),
          EtapaDelivery.fromMap({
            'id': '1',
            'nomeOpcao': 'AGUARDANDO',
            'nomeBotao': 'PREPARAR',
            'tipodeimpressao': '0',
            'vendas': [
              if (novo)
                pedidoTeste(campos: {'id': '28', 'numeroPedido': '28'}).dados
            ],
          }),
          EtapaDelivery.fromMap({
            'id': '2',
            'nomeOpcao': 'PREPARANDO',
            'tipodeimpressao': '1',
            'vendas': [emPreparo.dados],
          }),
        ];
    servico.respostaLista = () async => quadro();
    await tester
        .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AGUARDANDO (0)'));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum pedido nesta etapa'), findsOneWidget);
    final resposta = Completer<List<EtapaDelivery>>();
    servico.respostaLista = () => resposta.future;
    await tester.tap(find.byTooltip('Atualizar pedidos'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('delivery-carregando-1')), findsOneWidget);
    expect(find.text('Atualizando pedidos…'), findsOneWidget);
    expect(find.text('Nenhum pedido nesta etapa'), findsNothing);
    expect(find.text('PREPARANDO (1)'), findsOneWidget);
    resposta.complete(quadro(incluirLocal: false, novo: true));
    await tester.pumpAndSettle();
    expect(find.text('Atualizando pedidos…'), findsNothing);
    expect(find.textContaining('#28'), findsOneWidget);
    expect(find.text('AGUARDANDO (1)'), findsOneWidget);
    expect(find.text('2 pedidos'), findsOneWidget);
    expect(find.textContaining('No aparelho'), findsNothing);

    // Falha na consulta seguinte conserva o pedido e encerra o carregamento.
    final falha = Completer<List<EtapaDelivery>>();
    servico.respostaLista = () => falha.future;
    await tester.tap(find.byTooltip('Atualizar pedidos'));
    await tester.pump();
    expect(find.textContaining('#28'), findsOneWidget);
    falha.completeError(StateError('Sem conexao'));
    await tester.pumpAndSettle();
    expect(provedor.carregando, false);
    expect(provedor.erro, isNotNull);
    expect(find.textContaining('#28'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('mostra Aguardando enquanto uma consulta de configuracao ainda espera',
      () async {
    final servico = _ConfiguracaoLenta();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    final exibiuLista = Completer<void>();
    provedor.addListener(() {
      if (provedor.etapas.isNotEmpty && !exibiuLista.isCompleted) {
        exibiuLista.complete();
      }
    });
    final consulta = provedor.listar();
    try {
      await exibiuLista.future.timeout(const Duration(seconds: 1));
      expect(provedor.etapas.first.pedidos, isNotEmpty);
      expect(provedor.carregando, false);
      expect(servico.liberar.isCompleted, false);
    } finally {
      servico.liberar.complete(servico.config);
      await consulta;
    }
  });

  test('notificacao apos recibo da API nao recoloca Delivery em No aparelho',
      () async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    final local = pedidoTeste(campos: {
      'id': 'delivery-local:primeiro',
      'faseLocal': 'enfileirado',
      'idopcoescarrossel': 'local',
    });
    final outro = pedidoTeste(
        campos: {'id': 'delivery-local:outro', 'idopcoescarrossel': 'local'});
    servico.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': 'local',
            'vendas': [local.dados, outro.dados]
          }),
          EtapaDelivery.fromMap({
            'id': '1',
            'vendas': [pedidoTeste().dados]
          }),
        ];
    await provedor.listar();
    provedor.atualizarPedido(local);
    provedor.atualizarPedido(PedidoDelivery.fromMap({
      ...local.dados,
      'estadoSincronizacao': 'concluido',
      'idDeliveryConfirmado': '25',
      'preparoRedePendente': false,
    }));
    expect(provedor.etapas.first.pedidos.map((p) => p.id), [outro.id]);
    expect(provedor.etapas.last.pedidos.single.id, '25');
  });

  test('mantem Preparo via Wi-Fi enquanto sua etapa aguarda reconciliacao',
      () async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    servico.respostaLista = () async => [
          EtapaDelivery.fromMap({'id': '2', 'vendas': []}),
        ];
    await provedor.listar();
    final local = pedidoTeste(campos: {
      'id': 'delivery-local:preparo',
      'idopcoescarrossel': '2',
      'faseLocal': 'enfileirado',
      'estadoSincronizacao': 'concluido',
      'idDeliveryConfirmado': '25',
      'recebidoNaRede': true,
      'etapaDeliveryRede': 'preparando',
      'preparoRedePendente': true,
    });
    provedor.atualizarPedido(local);
    expect(provedor.etapas.single.pedidos.single.preparandoNaRede, true);
  });

  test(
      'ACK do PC tira imediatamente o pedido da etapa local mesmo com outro rascunho',
      () async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    final pedido = pedidoTeste(campos: {
      'id': 'delivery-local:rede',
      'idopcoescarrossel': 'local',
      'faseLocal': 'enfileirado'
    });
    servico.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': 'local',
            'vendas': [pedido.dados]
          })
        ];
    await provedor.listar();
    provedor.atualizarPedido(pedido);
    servico.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': 'local',
            'vendas': [
              pedidoTeste(campos: {'id': 'delivery-local:outro'}).dados
            ]
          }),
          EtapaDelivery.fromMap({
            'id': '1',
            'vendas': [
              {
                ...pedido.dados,
                'recebidoNaRede': true,
                'idopcoescarrossel': '1'
              }
            ]
          }),
        ];
    await provedor.listar();
    expect(provedor.etapas.first.pedidos.single.id, 'delivery-local:outro');
    expect(provedor.etapas.last.pedidos.single.id, pedido.id);
  });
  testWidgets('socket atualiza o mesmo delivery que esta visivel',
      (tester) async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    Modular.init(_Modulo(provedor));
    addTearDown(Modular.destroy);
    await tester.pumpWidget(const MaterialApp(home: PaginaDelivery()));
    await tester.pumpAndSettle();
    final antes = servico.consultas;
    servico.respostaLista = () async => [
          EtapaDelivery.fromMap(
              {'id': '99', 'nomeOpcao': 'Pedido recebido agora', 'vendas': []}),
        ];
    AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: 'delivery'));
    await tester.pumpAndSettle();
    expect(servico.consultas, antes + 1);
    expect(provedor.etapas.single.id, '99');
    expect(find.textContaining('Pedido recebido agora'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  test('confirmacao remota libera imediatamente mudancas de outro terminal',
      () async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    var etapaAtual = '1';
    final pedido = pedidoTeste();
    servico.respostaLista = () async => [
          for (final etapa in ['1', '2', '3'])
            EtapaDelivery.fromMap({
              'id': etapa,
              'vendas': [if (etapa == etapaAtual) pedido.comEtapa(etapa).dados]
            }),
        ];
    await provedor.listar();
    provedor.moverPedidoParaEtapa(pedido, '2');
    etapaAtual = '2';
    await provedor.listar();
    etapaAtual = '3';
    await provedor.listar();
    expect(provedor.etapas[1].pedidos, isEmpty);
    expect(provedor.etapas[2].pedidos.single.id, pedido.id);
  });
}
