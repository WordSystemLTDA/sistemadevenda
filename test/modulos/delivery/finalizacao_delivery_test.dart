import 'dart:async';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_acrescimo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_forma_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cardapio/finalizacao_carrinhos_test.dart';
import '../../suporte/captura_tela.dart';

class _DeliveryFinalizacao extends ServicoDelivery {
  _DeliveryFinalizacao(super.dio, super.usuario);

  @override
  Future<PagamentoRecorrente?> pagamentoRecorrente(String id) async {
    consultasRecorrencia++;
    if (falharRecorrencia) {
      throw StateError(
          'Não foi possível acessar os recorrentes. Verifique a conexão e a atualização da API.');
    }
    return null;
  }

  int envios = 0;
  int consultas = 0;
  int pagamentos = 0;
  int conclusoes = 0;
  int notificacoes = 0;
  int consultasRecorrencia = 0;
  MensagemClienteDelivery? ultimaMensagem;
  String? deliveryNotificado;
  String pago = '0';
  bool falharConsultaAposSalvar = false;
  bool falharEnvio = false;
  bool falharRecorrencia = false;
  bool recorrenteVinculado = false;
  Completer<void>? esperaEnvio;
  Completer<void>? consultaFinalBloqueada;

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    expect(rota, 'delivery/listar_opcoes_por_id.php');
    consultas++;
    if (conclusoes > 0 && consultaFinalBloqueada != null) {
      await consultaFinalBloqueada!.future;
    }
    if (envios > 0 && falharConsultaAposSalvar) {
      throw StateError('Falha na consulta do pedido salvo');
    }
    return {
      'sucesso': true,
      'dados': {
        'id': campos['id'],
        'idVenda': conclusoes > 0 ? '77' : '0',
        'idCliente': '209',
        'status': conclusoes > 0 ? 'Finalizado' : 'Pendente',
        'valorVenda': envios > 0 ? '14.00' : '4.00',
        'somaValorHistorico': pago,
        'recorrenteVinculado': recorrenteVinculado,
        'valordaentrega': '4.00',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    if (rota == 'delivery/inserir_produtos.php') {
      expect(campos['id_delivery'], '10118');
      expect(campos['produtos'], hasLength(1));
      if (falharEnvio) throw StateError('Não foi possível salvar.');
      envios++;
      await esperaEnvio?.future;
      return {'sucesso': true};
    }
    if (rota == 'delivery/pagar_pedido.php') {
      expect(campos['id'], '10118');
      pagamentos++;
      pago = campos['valor_lancamento']?.toString() ?? pago;
      return {'sucesso': true};
    }
    if (rota == 'delivery/finalizar_pedido_delivery.php') {
      expect(campos['id_delivery'], '10118');
      conclusoes++;
      return {'sucesso': true};
    }
    fail('Rota inesperada no delivery: $rota');
  }

  @override
  Future<String> notificarCliente(
    MensagemClienteDelivery mensagem, {
    String cliente = '0',
    String endereco = '0',
    String idDelivery = '0',
  }) async {
    notificacoes++;
    ultimaMensagem = mensagem;
    deliveryNotificado = idDelivery;
    return 'Enviado com sucesso!';
  }
}

class _ModuloDelivery extends ModuloFinalizacaoTeste {
  late final delivery = _DeliveryFinalizacao(api, usuario);

  @override
  void binds(Injector i) {
    super.binds(i);
    i.addInstance<ProvedorBalcao>(ProvedorBalcao(ServicoBalcao(api, usuario)));
    i.addInstance<ServicoDelivery>(delivery);
    i.addInstance<ServicoFinalizarPagamento>(
        ServicoFinalizarPagamento(api, usuario));
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  Future<_ModuloDelivery> abrir(WidgetTester tester,
      {TipoCardapio tipo = TipoCardapio.delivery}) async {
    SharedPreferences.setMockInitialValues({});
    const fonte = String.fromEnvironment('FONTE_TESTE');
    tester.view.physicalSize = Size(fonte.isEmpty ? 800 : 440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final m = _ModuloDelivery();
    m.api.cliente.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path.startsWith('/tela_nfe_saida/listar_bancos.php')) {
        handler
            .resolve(Response(requestOptions: options, data: <String, dynamic>{
          for (final sufixo in [
            'Pix',
            'Opcao2',
            'Opcao3',
            'Opcao4',
            'Opcao5'
          ]) ...{
            'idBanco$sufixo': '0',
            'ativoBanco$sufixo': 'Não',
            'nomeBanco$sufixo': '',
            'pixdinamico${sufixo.toLowerCase()}': 'Não',
          },
        }));
      } else {
        handler.next(options);
      }
    }));
    app.usuarioProvedor = m.usuario;
    Modular.init(m);
    addTearDown(() {
      m.servidor.dispose();
      m.carrinho.dispose();
      m.recorrentes.dispose();
      m.cardapio.dispose();
      m.usuario.dispose();
      m.api.cliente.close();
      Modular.destroy();
    });
    await m.selecionar('118', tipo: tipo);
    m.cardapio.tipo = tipo;
    await m.adicionar('Produto delivery', '1010');
    await m.montar(tester, tipo: tipo);
    await m.abrir(tester);
    return m;
  }

  testWidgets('delivery abre descontos e pagamento com o total da API e taxa',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(Modular.get<ProvedorFinalizarPagamento>().idVenda, '10118');
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 14);
    expect(m.delivery.envios, 1);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(m.api.pedidos, isEmpty);
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaSelecionarPagamento), findsOneWidget);
    expect(find.text('Dinheiro'), findsOneWidget);
    expect(
        tester
            .widget<PaginaSelecionarPagamento>(
                find.byType(PaginaSelecionarPagamento))
            .totalReceber,
        14);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('delivery permite pagar depois sem registrar pagamento',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaSelecionarPagamento), findsOneWidget);
    expect(find.text('Pagar depois'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pagar-depois-delivery')));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaSelecionarPagamento), findsNothing);
    expect(m.delivery.envios, 1);
    expect(m.delivery.pagamentos, 0);
    expect(m.delivery.conclusoes, 0);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('delivery comum sem pagamento ignora falha dos recorrentes',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.falharRecorrencia = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaSelecionarPagamento), findsOneWidget);
    expect(m.delivery.consultasRecorrencia, 0);
    expect(find.textContaining('recorrentes'), findsNothing);
    expect(find.text('Dinheiro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('delivery recorrente preserva erro da consulta de pagamento',
      (tester) async {
    final m = await abrir(tester);
    m.delivery
      ..recorrenteVinculado = true
      ..falharRecorrencia = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(m.delivery.consultasRecorrencia, 1);
    expect(find.textContaining('Não foi possível acessar os recorrentes'),
        findsOneWidget);
  });

  testWidgets('delivery com pagamento parcial preserva consulta protegida',
      (tester) async {
    final m = await abrir(tester);
    m.delivery
      ..pago = '5.00'
      ..falharRecorrencia = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(m.delivery.consultasRecorrencia, 1);
    expect(find.textContaining('Não foi possível acessar os recorrentes'),
        findsOneWidget);
  });

  testWidgets('delivery pergunta forma de pagamento sem selecionar ou cobrar',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    final perguntar =
        find.byKey(const ValueKey('perguntar-pagamento-delivery'));
    expect(perguntar, findsOneWidget);
    await tester.tap(perguntar);
    await tester.pumpAndSettle();

    expect(m.delivery.notificacoes, 1);
    expect(m.delivery.ultimaMensagem, MensagemClienteDelivery.formaPagamento);
    expect(m.delivery.deliveryNotificado, '10118');
    expect(m.delivery.pagamentos, 0);
    expect(m.delivery.conclusoes, 0);
    expect(find.byType(PaginaSelecionarPagamento), findsOneWidget);
    expect(find.text('Enviado com sucesso!'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('pagamento integral do delivery nao espera consulta final lenta',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarFormaPagamento), findsOneWidget);

    final consultasAntesDoPagamento = m.delivery.consultas;
    m.delivery.consultaFinalBloqueada = Completer<void>();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 2));

    expect(m.delivery.pagamentos, 1);
    expect(m.delivery.conclusoes, 1);
    expect(m.delivery.consultas, consultasAntesDoPagamento + 2);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);

    m.delivery.consultaFinalBloqueada!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('falha apos salvar preserva resumo e retoma sem duplicar pedido',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.falharConsultaAposSalvar = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaCarrinho), findsOneWidget);
    expect(find.byType(CardCarrinho), findsOneWidget);
    expect(find.text('Seu carrinho está vazio'), findsNothing);
    expect(tester.widget<BotaoAcaoPedido>(find.byType(BotaoAcaoPedido)).total,
        contains('10,00'));
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(m.delivery.envios, 1);

    m.delivery.falharConsultaAposSalvar = false;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 14);
    expect(m.delivery.envios, 1);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'falha ao salvar delivery conserva o carrinho para tentar de novo',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.falharEnvio = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(CardCarrinho), findsOneWidget);
    expect(find.byType(PaginaFinalizarAcrescimo), findsNothing);
    expect(m.carrinho.itensCarrinho.precoTotal, 10);
    m.delivery.falharEnvio = false;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(m.delivery.envios, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('dois toques em finalizar enviam uma unica vez', (tester) async {
    final m = await abrir(tester);
    m.delivery.esperaEnvio = Completer<void>();
    await tester.tap(find.text('Finalizar'));
    await tester.tap(find.text('Finalizar'));
    await tester.pump();
    expect(m.delivery.envios, 1);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, hasLength(1));
    m.delivery.esperaEnvio!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(m.delivery.envios, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('balcao abre descontos sem salvar no delivery ou limpar itens',
      (tester) async {
    final m = await abrir(tester, tipo: TipoCardapio.balcao);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 10);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, hasLength(1));
    expect(m.delivery.envios, 0);
    expect(m.delivery.consultas, 0);
    expect(m.api.pedidos, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('voltar dos descontos permite continuar sem reenviar os itens',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.pago = '5.00';
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 9);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CardCarrinho), findsOneWidget);
    expect(tester.widget<BotaoAcaoPedido>(find.byType(BotaoAcaoPedido)).total,
        contains('9,00'));
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 9);
    expect(m.delivery.envios, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final tipo in [TipoCardapio.mesa, TipoCardapio.comanda]) {
    testWidgets('${tipo.name} finaliza sem entrar no fluxo de delivery',
        (tester) async {
      final m = await abrir(tester, tipo: tipo);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      expect(m.api.pedidos, hasLength(1));
      expect(m.api.pedidos.single['id_comanda_pedido'], '10118');
      expect(m.servidor.impressos, hasLength(1));
      expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
      expect(find.text('Abrir carrinho'), findsOneWidget);
      expect(find.byType(PaginaFinalizarAcrescimo), findsNothing);
      expect(m.delivery.envios, 0);
      expect(m.delivery.consultas, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
