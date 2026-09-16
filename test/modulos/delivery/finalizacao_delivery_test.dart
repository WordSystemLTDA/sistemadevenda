import 'dart:async';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_acrescimo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cardapio/finalizacao_carrinhos_test.dart';
import '../../suporte/captura_tela.dart';

class _DeliveryFinalizacao extends ServicoDelivery {
  _DeliveryFinalizacao(super.dio, super.usuario);

  int envios = 0;
  int consultas = 0;
  bool falharConsultaAposSalvar = false;
  bool falharEnvio = false;
  Completer<void>? esperaEnvio;

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    expect(rota, 'delivery/listar_opcoes_por_id.php');
    consultas++;
    if (envios > 0 && falharConsultaAposSalvar) {
      throw StateError('Falha na consulta do pedido salvo');
    }
    return {
      'sucesso': true,
      'dados': {
        'id': campos['id'],
        'idVenda': '0',
        'idCliente': '209',
        'status': 'Pendente',
        'valorVenda': envios > 0 ? '14.00' : '4.00',
        'somaValorHistorico': '0',
        'valordaentrega': '4.00',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    expect(rota, 'delivery/inserir_produtos.php');
    expect(campos['id_delivery'], '10118');
    expect(campos['produtos'], hasLength(1));
    if (falharEnvio) throw StateError('Não foi possível salvar.');
    envios++;
    await esperaEnvio?.future;
    return {'sucesso': true};
  }
}

class _ModuloDelivery extends ModuloFinalizacaoTeste {
  late final delivery = _DeliveryFinalizacao(api, usuario);

  @override
  void binds(Injector i) {
    super.binds(i);
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
        handler.resolve(
            Response(requestOptions: options, data: <String, dynamic>{}));
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

  testWidgets('falha apos salvar preserva itens e retoma sem duplicar pedido',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.falharConsultaAposSalvar = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaCarrinho), findsOneWidget);
    expect(find.byType(CardCarrinho), findsOneWidget);
    expect(find.text('Seu carrinho está vazio'), findsNothing);
    expect(m.carrinho.itensCarrinho.precoTotal, 10);
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
}
