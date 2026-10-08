import 'dart:async';
import 'dart:convert';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/preferencia_confirmacao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_acrescimo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_conta_atendimento.dart';
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
import '../../essencial/utils/impressao_preparo_test.dart' as impressao;

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
  int confirmacoes = 0;
  int confirmacoesWhatsApp = 0;
  int notificacoes = 0;
  int consultasRecorrencia = 0;
  int alteracoesEntrega = 0;
  int cadastrosEndereco = 0;
  bool falharCadastroEndereco = false;
  bool falharAlteracaoEntrega = false;
  bool devolverIdEndereco = true;
  bool cadastrarOutroEnderecoSimultaneo = false;
  Map<String, dynamic>? camposEnderecoCadastrado;
  final enderecosCliente = <Map<String, dynamic>>[
    {
      'id': '17',
      'endereco': 'Rua Atual',
      'numero': '10',
      'bairro': 'Centro',
      'cidade': 'Cidade',
      'padrao': 'Sim',
      'valortaxabairro': '4.00',
    },
    {
      'id': '18',
      'endereco': 'Rua Nova',
      'numero': '20',
      'bairro': 'Bairro 2',
      'cidade': 'Cidade',
      'padrao': 'Não',
      'valortaxabairro': '7.00',
    },
  ];
  MensagemClienteDelivery? ultimaMensagem;
  PedidoDelivery? ultimoPedidoConfirmadoWhatsApp;
  String? formaPagamentoConfirmadaWhatsApp;
  String? deliveryNotificado;
  String? valorPedidoNotificado;
  final operacoesFinalizacao = <String>[];
  String pago = '0';
  bool falharConsultaAposSalvar = false;
  bool falharEnvio = false;
  bool falharRecorrencia = false;
  bool falharConfirmacaoWhatsApp = false;
  bool recorrenteVinculado = false;
  bool pagarDepoisConfirmado = false;
  String celularCliente = '(44) 99999-9999';
  String tipoEntrega = '1';
  String enderecoSelecionado = '17';
  double taxaEntrega = 4;
  Completer<void>? esperaEnvio;
  Completer<void>? esperaConfirmacaoWhatsApp;
  Completer<void>? consultaFinalBloqueada;
  Completer<void>? esperaEnderecosAposSelecao;

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'config_clientes/listar_cliente.php') {
      return <String, dynamic>{};
    }
    if (rota == 'delivery/notificarenviarchavepix.php') {
      return {'sucesso': true, 'ignorado': true};
    }
    if (rota == 'permissoes_bigchef/listar_permissoes_bigchef.php') {
      return {
        'formacobrancaentregadelivery': '2',
        'valordaentrega': '4.00',
        'valordiferenca': '0.00',
      };
    }
    if (rota == 'enderecos_clientes/listar_por_cliente.php') {
      expect(campos['cliente'], '209');
      if (enderecoSelecionado == '19') {
        await esperaEnderecosAposSelecao?.future;
      }
      return enderecosCliente;
    }
    expect(rota, 'delivery/listar_opcoes_por_id.php');
    consultas++;
    if (conclusoes > 0 && consultaFinalBloqueada != null) {
      await consultaFinalBloqueada!.future;
    }
    if (envios > 0 && falharConsultaAposSalvar) {
      throw StateError('Falha na consulta do pedido salvo');
    }
    final taxaAtual = tipoEntrega == '1' ? taxaEntrega : 0.0;
    final total = (envios > 0 ? 10.0 : 0.0) + taxaAtual;
    return {
      'sucesso': true,
      'dados': {
        'id': campos['id'],
        'idVenda': conclusoes > 0 ? '77' : '0',
        'idCliente': '209',
        'celularCliente': celularCliente,
        'status': conclusoes > 0 ? 'Finalizado' : 'Pendente',
        'valorVenda': total.toStringAsFixed(2),
        'somaValorHistorico': pago,
        'recorrenteVinculado': recorrenteVinculado,
        'valordaentrega': taxaAtual.toStringAsFixed(2),
        'tipodeentrega': tipoEntrega,
        'idendereco': enderecoSelecionado,
        'idopcoescarrossel': '10',
        'enderecoCliente':
            enderecoSelecionado == '18' ? 'Rua Nova' : 'Rua Atual',
        'numeroCliente': enderecoSelecionado == '18' ? '20' : '10',
        'bairroCliente': enderecoSelecionado == '18' ? 'Bairro 2' : 'Centro',
        'cidadeCliente': 'Cidade',
      },
    };
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    if (rota == 'clientes/inserir_endereco.php') {
      if (falharCadastroEndereco) {
        throw StateError('Não foi possível salvar o endereço.');
      }
      camposEnderecoCadastrado = Map<String, dynamic>.from(campos);
      final id = '${19 + cadastrosEndereco++}';
      enderecosCliente.add({
        ...campos,
        'id': id,
        'taxaentregacalculada': '9.50',
        'valortaxabairro': '2.00',
      });
      if (cadastrarOutroEnderecoSimultaneo) {
        enderecosCliente.insert(0, {
          'id': '999',
          'endereco': 'Outro cadastro',
          'numero': '999',
          'padrao': 'Não',
          'valortaxabairro': '20.00',
        });
      }
      return {
        'sucesso': true,
        if (devolverIdEndereco) 'dados': {'idEndereco': id},
      };
    }
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
      operacoesFinalizacao.add('pagamento');
      pago = campos['valor_lancamento']?.toString() ?? pago;
      return {'sucesso': true};
    }
    if (rota == 'delivery/finalizar_pedido_delivery.php') {
      expect(campos['id_delivery'], '10118');
      conclusoes++;
      operacoesFinalizacao.add('conclusao');
      return {'sucesso': true};
    }
    if (rota == 'delivery/confirmar_pedido.php') {
      expect(campos['id'], '10118');
      pagarDepoisConfirmado = campos['pagar_depois'] == true;
      confirmacoes++;
      operacoesFinalizacao.add('confirmacao-delivery');
      return {'sucesso': true};
    }
    if (rota == 'delivery/acoes_pedido.php' && campos['acao'] == 'entrega') {
      if (falharAlteracaoEntrega) {
        throw StateError('Não foi possível atualizar o Delivery.');
      }
      expect(campos['id'], '10118');
      expect(campos['statusOrigem'], '10');
      tipoEntrega = campos['tipo']?.toString() ?? tipoEntrega;
      enderecoSelecionado = campos['endereco']?.toString() ?? '0';
      taxaEntrega = double.tryParse('${campos['taxa']}') ?? 0;
      alteracoesEntrega++;
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
    String valorPedido = '',
  }) async {
    notificacoes++;
    ultimaMensagem = mensagem;
    deliveryNotificado = idDelivery;
    valorPedidoNotificado = valorPedido;
    return 'Enviado com sucesso!';
  }

  @override
  Future<Map<String, dynamic>> notificarConfirmacaoPedido(
    PedidoDelivery pedido, {
    String? formaPagamento,
  }) async {
    confirmacoesWhatsApp++;
    ultimoPedidoConfirmadoWhatsApp = pedido;
    formaPagamentoConfirmadaWhatsApp = formaPagamento;
    operacoesFinalizacao.add('whatsapp');
    if (falharConfirmacaoWhatsApp) {
      throw StateError('WhatsApp indisponível');
    }
    await esperaConfirmacaoWhatsApp?.future;
    return {'sucesso': true};
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

  test('retorno da finalizacao respeita a origem do Delivery', () {
    final provedor = ProvedorFinalizarPagamento();
    expect(provedor.rotaRetornoDelivery, 'PaginaDelivery');

    provedor.definirContextoDelivery(recorrenteVinculado: true);
    expect(provedor.rotaRetornoDelivery, 'PaginaRecorrentes');

    provedor.definirContextoDelivery(recorrenteVinculado: false);
    expect(provedor.rotaRetornoDelivery, 'PaginaDelivery');
  });

  test('confirmacao local usa os produtos que ainda estao no carrinho', () {
    final produto = impressao.produto(nome: 'Pizza')
      ..valorVenda = '84'
      ..quantidade = 1;
    final pedido = PedidoDelivery.fromMap({
      'id': 'delivery-local:teste',
      'idCliente': '209',
      'celularCliente': '(44) 99999-9999',
      'tipodeentrega': '1',
      'valordaentrega': '4.00',
      'valorVenda': '4.00',
      'produtos': const <dynamic>[],
    });

    final confirmacao = montarConfirmacaoPedidoCarrinho(
      pedido: pedido,
      novosItens: [produto],
      valorNovosItens: 84,
      pedidoRegistrado: false,
    );

    expect(confirmacao.produtos, hasLength(1));
    expect(confirmacao.produtos.single.nome, 'Pizza');
    expect(confirmacao.taxaEntrega, 4);
    expect(confirmacao.total, 88);
  });

  Future<_ModuloDelivery> abrir(WidgetTester tester,
      {TipoCardapio tipo = TipoCardapio.delivery,
      String celularCliente = '(44) 99999-9999'}) async {
    // O socket da fixture representa o servidor Local, incluindo os ACKs.
    // Preferencias vazias usam Online e exigem o escopo do canal da empresa.
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'Cozinha', 'porta': '9980'})
    });
    const fonte = String.fromEnvironment('FONTE_TESTE');
    tester.view.physicalSize = Size(fonte.isEmpty ? 800 : 440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final m = _ModuloDelivery();
    m.delivery.celularCliente = celularCliente;
    m.api.celularCliente = celularCliente;
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
    expect(m.delivery.confirmacoes, 0);
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

  Future<void> cadastrarEndereco(WidgetTester tester,
      {String rua = 'Rua Cadastrada'}) async {
    await tester.tap(find.byKey(const ValueKey('novo-endereco-finalizacao')));
    await tester.pumpAndSettle();
    expect(find.text('Novo endereço'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('endereco-endereco')), rua);
    await tester.enterText(find.byKey(const ValueKey('endereco-numero')), '30');
    await tester.drag(find.byType(ListView), const Offset(0, -650));
    await tester.pumpAndSettle();
    expect(
        find.widgetWithText(SwitchListTile, 'Endereço padrão'), findsNothing);
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();
  }

  for (final noPagamento in [false, true]) {
    testWidgets(
        'novo endereço na ${noPagamento ? 'forma de pagamento' : 'tela de descontos'} seleciona só nesta venda e mantém seleção entre telas',
        (tester) async {
      final m = await abrir(tester);
      tester.view.physicalSize = const Size(440, 956);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      if (noPagamento) {
        await tester.tap(find.text('Avançar'));
        await tester.pumpAndSettle();
      }
      final botao = find.byKey(const ValueKey('novo-endereco-finalizacao'));
      expect(botao, findsOneWidget);
      expect(tester.getCenter(botao).dy,
          closeTo(tester.getCenter(find.text('Opções de Endereço')).dy, 12));
      await cadastrarEndereco(tester);

      expect(m.delivery.cadastrosEndereco, 1);
      expect(m.delivery.camposEnderecoCadastrado!['idCliente'], '209');
      expect(m.delivery.camposEnderecoCadastrado!['padrao'], 'Não');
      expect(m.delivery.camposEnderecoCadastrado!['substituirPadrao'], isFalse);
      expect(m.delivery.enderecosCliente.first['padrao'], 'Sim');
      expect(m.delivery.enderecosCliente.last['padrao'], 'Não');
      expect(m.delivery.enderecoSelecionado, '19');
      expect(m.delivery.taxaEntrega, 9.5);
      expect(m.delivery.alteracoesEntrega, 1);
      final pagamento = Modular.get<ProvedorFinalizarPagamento>();
      expect(pagamento.pedidoDelivery!.texto('idendereco'), '19');
      expect(pagamento.ultimoEnderecoDelivery, '19');
      expect(pagamento.valor, 19.5);
      expect(find.textContaining('Rua Cadastrada, 30'), findsOneWidget);
      expect(find.textContaining('19,50'), findsWidgets);

      if (noPagamento) {
        await tester.pageBack();
      } else {
        await tester.tap(find.text('Avançar'));
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Rua Cadastrada, 30'), findsOneWidget);
      expect(find.textContaining('19,50'), findsWidgets);
      await tester
          .tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-2')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-1')));
      await tester.pumpAndSettle();
      expect(m.delivery.enderecoSelecionado, '19');
      expect(m.delivery.taxaEntrega, 9.5);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('cancelar novo endereço mantém endereço e total atuais',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('novo-endereco-finalizacao')));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(m.delivery.cadastrosEndereco, 0);
    expect(m.delivery.alteracoesEntrega, 0);
    expect(m.delivery.enderecoSelecionado, '17');
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 14);
    expect(
        tester
            .widget<IconButton>(
                find.byKey(const ValueKey('novo-endereco-finalizacao')))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('consulta lenta da tela anterior não restaura modalidade antiga',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    final espera = Completer<void>();
    m.delivery.esperaEnderecosAposSelecao = espera;
    await cadastrarEndereco(tester);
    expect(m.delivery.enderecoSelecionado, '19');
    await tester.tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-2')));
    await tester.pumpAndSettle();
    espera.complete();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Sem taxa de entrega'), findsOneWidget);
    expect(m.cardapio.tipodeentrega, '2');
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 10);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('primeiro endereço do cliente fica selecionado sem virar padrão',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.enderecosCliente.clear();
    m.delivery.tipoEntrega = '2';
    m.delivery.taxaEntrega = 0;
    m.delivery.enderecoSelecionado = '0';
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await cadastrarEndereco(tester);
    expect(m.delivery.enderecosCliente.single['padrao'], 'Não');
    expect(m.delivery.tipoEntrega, '1');
    expect(m.delivery.enderecoSelecionado, '19');
    expect(m.delivery.taxaEntrega, 9.5);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('seleciona endereço salvo mesmo com outro cadastro simultâneo',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.cadastrarOutroEnderecoSimultaneo = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await cadastrarEndereco(tester);
    expect(m.delivery.enderecosCliente.first['id'], '999');
    expect(m.delivery.enderecoSelecionado, '19');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('seleciona novo endereço com API que não devolve o código salvo',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.devolverIdEndereco = false;
    m.delivery.cadastrarOutroEnderecoSimultaneo = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await cadastrarEndereco(tester);
    expect(m.delivery.enderecoSelecionado, '19');
    expect(m.delivery.alteracoesEntrega, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('falha no cadastro mantém formulário e não altera a venda',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.falharCadastroEndereco = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await cadastrarEndereco(tester);
    expect(find.text('Não foi possível salvar o endereço.'), findsOneWidget);
    expect(m.delivery.cadastrosEndereco, 0);
    expect(m.delivery.alteracoesEntrega, 0);
    expect(m.delivery.enderecoSelecionado, '17');
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 14);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'falha ao selecionar endereço salvo mantém venda e permite tentar',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.falharAlteracaoEntrega = true;
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await cadastrarEndereco(tester);
    expect(m.delivery.cadastrosEndereco, 1);
    expect(find.text('Não foi possível atualizar o Delivery.'), findsOneWidget);
    expect(m.delivery.enderecoSelecionado, '17');
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 14);
    m.delivery.falharAlteracaoEntrega = false;
    await tester.tap(find.byKey(const ValueKey('opcoes-endereco-finalizacao')));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Rua Cadastrada').hitTestable().last);
    await tester.pumpAndSettle();
    expect(m.delivery.enderecoSelecionado, '19');
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 19.5);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'finalizacao delivery altera modalidade endereco taxa e total nas duas telas',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    for (final tipo in ['1', '2', '3']) {
      expect(find.byKey(ValueKey('tipo-entrega-finalizacao-$tipo')),
          findsOneWidget);
    }
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('tipo-entrega-finalizacao-1')))
          .dy,
      lessThan(tester.getTopLeft(find.text('A PAGAR')).dy),
    );
    expect(find.text('Opções de Endereço'), findsOneWidget);
    expect(find.textContaining('Rua Nova').hitTestable(), findsNothing);
    expect(find.textContaining('14,00'), findsWidgets);

    final descontoPercentual = find.byWidgetPredicate((widget) =>
        widget is TextField && widget.decoration?.labelText == 'Desconto (%)');
    await tester.enterText(descontoPercentual, '10');
    await tester.pump();
    expect(find.textContaining('12,60'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-2')));
    await tester.pumpAndSettle();

    expect(m.delivery.tipoEntrega, '2');
    expect(m.delivery.taxaEntrega, 0);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 10);
    expect(find.textContaining('9,00'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-1')));
    await tester.pumpAndSettle();
    expect(m.delivery.tipoEntrega, '1');
    expect(m.delivery.taxaEntrega, 4);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 14);
    expect(find.textContaining('12,60'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('opcoes-endereco-finalizacao')));
    await tester.pumpAndSettle();
    final novoEndereco = find.textContaining('Rua Nova').hitTestable();
    expect(novoEndereco, findsOneWidget);
    await tester.tap(novoEndereco);
    await tester.pumpAndSettle();

    expect(m.delivery.enderecoSelecionado, '18');
    expect(m.delivery.taxaEntrega, 7);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 17);
    expect(find.textContaining('15,30'), findsWidgets);

    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaSelecionarPagamento), findsOneWidget);
    for (final tipo in ['1', '2', '3']) {
      expect(find.byKey(ValueKey('tipo-entrega-finalizacao-$tipo')),
          findsOneWidget);
    }
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('tipo-entrega-finalizacao-1')))
          .dy,
      lessThan(tester.getTopLeft(find.text('A PAGAR')).dy),
    );
    expect(find.text('Opções de Endereço'), findsOneWidget);
    expect(find.textContaining('Rua Atual').hitTestable(), findsNothing);
    expect(find.textContaining('15,30'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-3')));
    await tester.pumpAndSettle();

    expect(m.delivery.tipoEntrega, '3');
    expect(m.delivery.taxaEntrega, 0);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 10);
    expect(find.textContaining('9,00'), findsWidgets);
    expect(m.delivery.alteracoesEntrega, 4);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    expect(find.text('Sem taxa de entrega'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tipo-entrega-finalizacao-1')));
    await tester.pumpAndSettle();

    expect(m.delivery.tipoEntrega, '1');
    expect(m.delivery.enderecoSelecionado, '18');
    expect(m.delivery.taxaEntrega, 7);
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 17);
    expect(m.delivery.alteracoesEntrega, 5);
    expect(find.textContaining('15,30'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('carrinho do delivery envia o pedido completo pelo WhatsApp',
      (tester) async {
    final m = await abrir(tester);
    final botao = find.byKey(const ValueKey('enviar-pedido-whats-delivery'));

    expect(botao, findsOneWidget);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(m.delivery.confirmacoesWhatsApp, 1);
    expect(m.delivery.formaPagamentoConfirmadaWhatsApp, isNull);
    expect(m.delivery.pagamentos, 0);
    expect(m.delivery.conclusoes, 0);
    expect(m.delivery.envios, 0);
    expect(m.delivery.ultimoPedidoConfirmadoWhatsApp?.produtos, hasLength(1));
    expect(m.delivery.ultimoPedidoConfirmadoWhatsApp?.total, 14);
    expect(find.byType(PaginaCarrinho), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('carrinho esconde envio pelo WhatsApp se cliente nao tem celular',
      (tester) async {
    await abrir(tester, celularCliente: 'Sem Celular');

    expect(find.byKey(const ValueKey('enviar-pedido-whats-delivery')),
        findsNothing);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(tester.takeException(), isNull);
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
    expect(m.delivery.confirmacoes, 1);
    expect(m.delivery.pagarDepoisConfirmado, isTrue);
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

  testWidgets(
      'recebimento obrigatorio usa fluxo normal e retorna sem finalizar delivery',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    final pagamento = Modular.get<ProvedorFinalizarPagamento>();
    final pedido = await m.delivery.pedido('10118');
    pagamento.idVenda = pedido.id;
    pagamento.valor = pedido.restante;
    pagamento.definirContextoDelivery(
      recorrenteVinculado: pedido.recorrenteVinculado,
      pedido: pedido,
      recebimentoObrigatorio: true,
    );

    bool? recebeu;
    final contexto = tester.element(find.byType(PaginaCarrinho));
    unawaited(Navigator.of(contexto)
        .push<bool>(MaterialPageRoute(
          settings: const RouteSettings(
            name: ProvedorFinalizarPagamento.rotaRecebimentoObrigatorioDelivery,
          ),
          builder: (_) => const PaginaFinalizarAcrescimo(),
        ))
        .then((resultado) => recebeu = resultado));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaFinalizarAcrescimo), findsOneWidget);
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pagar-depois-delivery')), findsNothing);
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(recebeu, isTrue);
    expect(m.delivery.pagamentos, 1);
    expect(m.delivery.conclusoes, 0);
    expect(m.delivery.confirmacoes, 0);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
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

  testWidgets('somente delivery em dinheiro pode perguntar sobre o troco',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    final perguntar = find.byKey(const ValueKey('perguntar-troco-delivery'));
    expect(perguntar, findsOneWidget);
    await tester.tap(perguntar);
    await tester.pumpAndSettle();

    expect(m.delivery.notificacoes, 1);
    expect(m.delivery.ultimaMensagem, MensagemClienteDelivery.perguntarTroco);
    expect(m.delivery.deliveryNotificado, '10118');
    expect(m.delivery.valorPedidoNotificado, '14.00');
    expect(m.delivery.pagamentos, 0);
    expect(find.text('Enviado com sucesso!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('outras formas nao mostram a pergunta de troco no delivery',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Débito'));
    await tester.pump();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    expect(
        find.byKey(const ValueKey('perguntar-troco-delivery')), findsNothing);
    expect(find.byKey(const ValueKey('habilitar-confirmacao-pedido-delivery')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'confirmacao automatica fica salva e ocorre depois de finalizar delivery',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();

    final preferencia =
        find.byKey(const ValueKey('habilitar-confirmacao-pedido-delivery'));
    expect(tester.widget<SwitchListTile>(preferencia).value, isFalse);
    await tester.tap(preferencia);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PreferenciaConfirmacaoDelivery.chave), isTrue);

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(m.delivery.confirmacoesWhatsApp, 1);
    expect(m.delivery.formaPagamentoConfirmadaWhatsApp, 'Dinheiro');
    expect(m.delivery.operacoesFinalizacao, [
      'pagamento',
      'conclusao',
      'confirmacao-delivery',
      'whatsapp',
    ]);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('finalizacao aguarda a confirmacao do WhatsApp antes de sair',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const ValueKey('habilitar-confirmacao-pedido-delivery')));
    await tester.pumpAndSettle();
    m.delivery.esperaConfirmacaoWhatsApp = Completer<void>();

    await tester.tap(find.text('Finalizar'));
    await tester.pump();

    expect(m.delivery.conclusoes, 1);
    expect(m.delivery.confirmacoes, 1);
    expect(m.delivery.confirmacoesWhatsApp, 1);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsOneWidget);

    m.delivery.esperaConfirmacaoWhatsApp!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('falha do WhatsApp nao desfaz a finalizacao do delivery',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(
        find.byKey(const ValueKey('habilitar-confirmacao-pedido-delivery')));
    await tester.pumpAndSettle();
    m.delivery.falharConfirmacaoWhatsApp = true;

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(m.delivery.pagamentos, 1);
    expect(m.delivery.conclusoes, 1);
    expect(m.delivery.confirmacoes, 1);
    expect(m.delivery.confirmacoesWhatsApp, 1);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
    expect(find.textContaining('Pedido finalizado, mas a confirmação não foi'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('desabilitar confirmacao salva a opcao e para os envios',
      (tester) async {
    final m = await abrir(tester);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Avançar'));
    await tester.pumpAndSettle();
    final preferencia =
        find.byKey(const ValueKey('habilitar-confirmacao-pedido-delivery'));

    await tester.tap(preferencia);
    await tester.pumpAndSettle();
    await tester.tap(preferencia);
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(PreferenciaConfirmacaoDelivery.chave), isFalse);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(m.delivery.confirmacoesWhatsApp, 0);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 31));
  });

  testWidgets('controles de WhatsApp nao aparecem fora do delivery',
      (tester) async {
    await abrir(tester, tipo: TipoCardapio.balcao);
    expect(find.byKey(const ValueKey('enviar-pedido-whats-delivery')),
        findsNothing);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('tipo-entrega-finalizacao-1')), findsNothing);
    expect(find.text('Opções de Endereço'), findsNothing);
    expect(find.byType(PaginaFinalizarContaAtendimento), findsOneWidget);
    expect(
        find.byKey(const ValueKey('perguntar-troco-delivery')), findsNothing);
    expect(find.byKey(const ValueKey('habilitar-confirmacao-pedido-delivery')),
        findsNothing);
    expect(tester.takeException(), isNull);
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
    expect(m.delivery.confirmacoes, 1);
    expect(m.delivery.confirmacoesWhatsApp, 0);
    expect(m.delivery.consultas, consultasAntesDoPagamento + 2);
    expect(find.byType(PaginaFinalizarFormaPagamento), findsNothing);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);

    m.delivery.consultaFinalBloqueada!.complete();
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 31));
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

  testWidgets('balcao salva os itens e abre a finalizacao segura',
      (tester) async {
    final m = await abrir(tester, tipo: TipoCardapio.balcao);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(find.byType(PaginaFinalizarContaAtendimento), findsOneWidget);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(m.delivery.envios, 0);
    expect(m.delivery.consultas, 0);
    expect(m.api.pedidos, hasLength(1));
    expect(m.api.pedidos.single['produtos'], hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('voltar dos descontos permite continuar sem reenviar os itens',
      (tester) async {
    final m = await abrir(tester);
    m.delivery.pago = '5.00';
    m.carrinho.itensCarrinho.listaComandosPedidos.single
      ..idCategoriaCardapio = '9'
      ..observacao = 'Conferência após voltar do pagamento';
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(Modular.get<ProvedorFinalizarPagamento>().valor, 9);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(CardCarrinho), findsOneWidget);
    expect(
        tester.widget<CardCarrinho>(find.byType(CardCarrinho)).somenteLeitura,
        isTrue);
    await tester.tap(find.byTooltip('Mostrar detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Conferência após voltar do pagamento'), findsOneWidget);
    expect(find.text('Editar Produto'), findsNothing);
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
