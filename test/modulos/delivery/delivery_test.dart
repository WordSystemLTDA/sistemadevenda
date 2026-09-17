import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../essencial/utils/impressao_preparo_test.dart' as impressao;

PedidoDelivery pedidoTeste({Map<String, dynamic> campos = const {}}) =>
    PedidoDelivery.fromMap({
      'id': '25',
      'idVenda': '0',
      'numeroPedido': '14',
      'idCliente': '4',
      'nomeCliente': 'Bruno Masson',
      'status': 'Pendente',
      'idopcoescarrossel': '1',
      'quantidadeprodutos': '2',
      'tipodeentrega': '1',
      'valorVenda': '86.00',
      'somaValorHistorico': '0',
      'enderecoCliente': 'Rua das Flores',
      'numeroCliente': '123',
      'bairroCliente': 'Centro',
      'cidadeCliente': 'Sao Paulo',
      'dataAbertura': DateTime.now().toIso8601String(),
      ...campos,
    });

List<EtapaDelivery> etapasTeste() => [
      for (final (id, nome, botao, tipo) in [
        ('1', 'Recebidos', 'Iniciar preparo', '0'),
        ('2', 'Em preparo', 'Despachar', '1'),
        ('3', 'Em entrega', 'Concluir pedido', '2'),
        ('4', 'Concluidos', '', '3'),
      ])
        EtapaDelivery.fromMap({
          'id': id,
          'nomeOpcao': nome,
          'nomeBotao': botao,
          'tipodeimpressao': tipo,
          'vendas': [
            pedidoTeste(campos: {
              'id': id,
              'numeroPedido': id,
              'idopcoescarrossel': id,
              if (id == '4') 'idVenda': '100'
            }).dados,
          ],
        }),
    ];

class DioFalso extends Fake implements DioCliente {}

class ServicoDeliveryTeste extends ServicoDelivery {
  ServicoDeliveryTeste()
      : super(
            DioFalso(),
            UsuarioProvedor()
              ..setUsuario(
                  UsuarioModelo(id: '2', empresa: '3', nome: 'Operador')));
  final gravacoes = <(String, Map<String, dynamic>)>[];
  PedidoDelivery atual = pedidoTeste();
  bool falhar = false;
  int consultas = 0;
  ConfigDelivery config =
      const ConfigDelivery(receberNoFinal: true, imprimirPreparo: false);
  List<Modelowordprodutos> produtosCardapio = [];
  Future<List<EtapaDelivery>> Function()? respostaLista;
  @override
  Future<List<EtapaDelivery>> listar(
      {required DateTime inicio,
      required DateTime fim,
      required String horaInicio,
      required String horaFim,
      String pesquisa = '',
      String tipo = '0'}) async {
    consultas++;
    if (falhar) throw StateError('Sem conexao');
    return await respostaLista?.call() ?? etapasTeste();
  }

  @override
  Future<ConfigDelivery> configuracao() async => config;
  @override
  Future<PedidoDelivery> pedido(String id) async => atual;
  @override
  Future<Modeloworddadoscardapio> dadosCardapio(String id) async =>
      Modeloworddadoscardapio(
          id: id,
          produtos: [...produtosCardapio],
          enderecoCliente: 'Rua A',
          numeroCliente: '12',
          bairroCliente: 'Bairro de entrega',
          nomeEmpresa: 'Pizzaria Teste');
  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'tela_nfe_saida/listar_bancos.php') {
      return {'ativoBancoPix': 'Sim', 'nomeBancoPix': 'Pix'};
    }
    if (rota == 'config_bigchef/listar.php') {
      return {'formacobrancaentregadelivery': '1', 'valordaentrega': '5'};
    }
    if (rota == 'config_clientes/listar_cliente.php') {
      return {
        'padrao_cep': '86.770-000',
        'padrao_nome_cidade': 'Santa Fe',
        'padrao_estado': 'PR',
        'bloquear_edicao_cidade': 'Sim',
        'requerido_endereco': 'Sim',
      };
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    gravacoes.add((rota, campos));
    if (rota == 'delivery/mudar_status_delivery.php') {
      atual = PedidoDelivery.fromMap(
          {...atual.dados, 'idopcoescarrossel': campos['status']});
    }
    return {
      'sucesso': true,
      'dados': {'idDelivery': '25'}
    };
  }
}

class AdaptadorDelivery extends Fake implements HttpClientAdapter {
  final chamadas = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    return ResponseBody.fromString('{"sucesso":true,"dados":[]}', 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('le valores brasileiros e do PHP sem perder milhares', () {
    expect(valorDelivery('1.234,56'), 1234.56);
    expect(valorDelivery('1,234.56'), 1234.56);
    expect(valorDelivery('86.00'), 86);
    expect(valorDelivery('NaN'), 0);
    expect(valorDelivery(null), 0);
    expect(
        pedidoTeste(campos: {
          'valorVenda': '1.234,56',
          'somaValorHistorico': '234,56'
        }).restante,
        1000);
  });
  test('identifica venda concluida mesmo quando status permanece pendente', () {
    expect(pedidoTeste().encerrado, isFalse);
    expect(pedidoTeste(campos: {'idVenda': '78'}).encerrado, isTrue);
    expect(pedidoTeste(campos: {'status': 'Cancelado'}).encerrado, isTrue);
  });
  test(
      'respeita recebimento no final e taxa por bairro com diferenca de horario',
      () {
    final config = ConfigDelivery.fromMap({
      'receberpedidonofinal': 'Sim',
      'formacobrancaentregadelivery': '2',
      'valordiferenca': '2.50',
      'entregadorfixo': '1',
      'identregador': '0'
    });
    expect(config.exigePagamento(pedidoTeste(), etapasTeste()[1]), isFalse);
    expect(config.exigePagamento(pedidoTeste(), etapasTeste().last), isTrue);
    expect(config.taxaEntrega('6.00'), 8.5);
    expect(config.entregadorFixo, isEmpty);
    final configNumero = ConfigDelivery.fromMap({
      'ativarnumerooperacionalpedido': 'Sim',
      'imprimirnumerooperacionalentregador': 'Sim',
      'imprimirnumerooperacionalconsumacao': 'Não',
      'imprimirnumerooperacionalpreparo': 'Sim',
      'numerodopedidodestaquecomprovante': 'Sim',
      'numerodopedidodestaquepreparo': 'Sim',
    });
    expect(configNumero.controlaNumeroOperacionalPedido, isTrue);
    expect(configNumero.imprimeNumeroOperacionalEntregador, isTrue);
    expect(configNumero.imprimeNumeroOperacionalConsumacao, isFalse);
    expect(configNumero.imprimeNumeroOperacionalPreparo, isTrue);
    expect(
        const ConfigDelivery(cobrancaEntrega: '1', valorEntrega: '4')
            .taxaEntrega('9'),
        4);
  });
  test('API de venda permanece no mesmo servidor configurado', () {
    for (final versao in ['api1', 'api6']) {
      expect(
          ServicoDelivery.enderecoApi(
                  'https://exemplo/sistema/apis_restaurantes/api_restaurantes_venda/$versao/')
              .toString(),
          'https://exemplo/sistema/apis_restaurantes/api_restaurantes_venda/$versao/');
    }
  });
  test('consulta envia empresa e usuario e nunca usa cache de outro modulo',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'})
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery();
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '3'));
    final servico = ServicoDelivery(dio, usuario);
    await servico.listar(
        inicio: DateTime(2026, 9, 16),
        fim: DateTime(2026, 9, 16),
        horaInicio: '05:00:00',
        horaFim: '05:00:00');
    final r = adapter.chamadas.single;
    expect(r.uri.path,
        '/sistema/apis_restaurantes/api_restaurantes_venda/api1/delivery/listar_opcoes.php');
    expect(r.queryParameters['empresa'], '3');
    expect(r.queryParameters['id_usuario'], '2');
    expect(r.extra['semCache'], isTrue);
  });
  test('pagamento calcula troco sem limpar pagamentos ou alterar produtos',
      () async {
    final s = ServicoDeliveryTeste();
    await s.pagar(pedidoTeste(), 1, 100);
    final p = s.gravacoes.single.$2;
    expect(p['valor_lancamento'], '100.00');
    expect(p['valortroco'], '14.00');
    expect(p['limpar_pagamentos_anteriores'], '0');
    expect(p['produtosParaFinalizar'], isEmpty);
    await expectLater(s.pagar(pedidoTeste(), 4, 100), throwsStateError);
    await expectLater(s.pagar(pedidoTeste(campos: {'idVenda': '2'}), 1, 86),
        throwsStateError);
    expect(s.gravacoes, hasLength(1));
  });
  test('pagamento parcial conserva o restante sem cobrar novamente o recebido',
      () async {
    final s = ServicoDeliveryTeste();
    await s.pagar(pedidoTeste(campos: {'somaValorHistorico': '40'}), 4, 20);
    expect(s.gravacoes.single.$2['valorAPagar'], '46.00');
    expect(s.gravacoes.single.$2['valortroco'], '0.00');
  });
  test('nao cadastra entrega sem cliente ou endereco', () async {
    final s = ServicoDeliveryTeste();
    await expectLater(
        s.criar(cliente: '0', endereco: '0', tipo: '1', observacao: ''),
        throwsStateError);
    expect(s.gravacoes, isEmpty);
    expect(
        await s.criar(
            cliente: '0', endereco: '0', tipo: '2', observacao: 'Retirar'),
        '25');
    expect(s.gravacoes.single.$2['tipoentrega'], '2');
  });
  test('nao insere produtos em pedido concluido nem envia lista vazia',
      () async {
    final s = ServicoDeliveryTeste();
    await expectLater(s.inserirProdutos('25', []), throwsStateError);
    s.atual = pedidoTeste(campos: {'idVenda': '78'});
    await expectLater(
        s.inserirProdutos('25', [impressao.produto()]), throwsStateError);
    expect(s.gravacoes, isEmpty);
  });
  test('comprovante usa endereco de entrega e destino de cada computador', () {
    final s = ServicoDeliveryTeste();
    final pedido = pedidoTeste().comEndereco(Modeloworddadoscardapio(
        enderecoCliente: 'Rua correta',
        numeroCliente: '5',
        bairroCliente: 'Bairro correto'));
    final mensagens = ImpressaoDelivery.comprovantes(s, pedido, [
      impressao.produto(computador: 'CAIXA'),
      impressao.produto(computador: 'COZINHA')
    ]);
    expect(mensagens, hasLength(2));
    final json = jsonDecode(mensagens.first) as Map;
    expect(json['tipo'], 'Delivery');
    expect(json['tipoImpressao'], '3');
    expect(json['bairroCliente'], 'Bairro correto');
    expect(json['nomedopc'], 'CAIXA');
    expect(json['numeroPedido'], '14');
    expect(json['comanda'], 'Delivery 25');
    expect(json['protocoloImpressao'], 2);
  });
  test('comprovante envia configuracao do numero operacional ao servidor', () {
    final s = ServicoDeliveryTeste();
    final mensagens = ImpressaoDelivery.comprovantes(
      s,
      pedidoTeste(),
      [impressao.produto(computador: 'CAIXA')],
      config: const ConfigDelivery(
        ativarnumerooperacionalpedido: 'Sim',
        imprimirnumerooperacionalentregador: 'Sim',
        imprimirnumerooperacionalconsumacao: 'Não',
        imprimirnumerooperacionalpreparo: 'Sim',
        numerodopedidodestaquecomprovante: 'Sim',
        numerodopedidodestaquepreparo: 'Não',
      ),
    );
    final json = jsonDecode(mensagens.single) as Map;
    expect(json['ativarnumerooperacionalpedido'], 'Sim');
    expect(json['imprimirnumerooperacionalentregador'], 'Sim');
    expect(json['imprimirnumerooperacionalconsumacao'], 'Não');
    expect(json['imprimirnumerooperacionalpreparo'], 'Sim');
    expect(json['numerodopedidodestaquecomprovante'], 'Sim');
    expect(json['numerodopedidodestaquepreparo'], 'Não');
  });
  test('preparo do delivery imprime detalhes da pizza e mantem destino',
      () async {
    final servidor = impressao.ServidorTeste();
    Modular.init(impressao.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);

    final s = ServicoDeliveryTeste();
    final produtoCardapio = impressao.produto(
        id: '1', nome: 'Pizza', codigo: '2', computador: 'COZINHA')
      ..iditensvenda = '99';
    final pizzaDetalhada = impressao.produto(id: '1', nome: 'Pizza')
      ..iditensvenda = '99'
      ..observacao = 'Sem cebola'
      ..opcoesPacotesListaFinal = [
        impressao.saboresPizza(),
        impressao.bordas(['Cheddar', 'Catupiry']),
        impressao.adicionais(['Milho']),
      ];
    s.produtosCardapio = [produtoCardapio];
    s.atual = pedidoTeste(campos: {
      'produtos': [pizzaDetalhada.toMap()],
    });
    s.config = const ConfigDelivery(
      ativarnumerooperacionalpedido: 'Sim',
      imprimirnumerooperacionalpreparo: 'Sim',
      numerodopedidodestaquepreparo: 'Sim',
    );

    await ImpressaoDelivery.imprimir(s, servidor, s.atual, preparo: true);

    final mensagem = servidor.mensagens.single;
    final produto = (mensagem['produtos'] as List).single as Map;
    final opcoes = produto['opcoesPacotesListaFinal'] as List;

    expect(mensagem['tipoImpressao'], '1');
    expect(mensagem['nomedopc'], 'COZINHA');
    expect(mensagem['numeroPedido'], '14');
    expect(mensagem['ativarnumerooperacionalpedido'], 'Sim');
    expect(mensagem['imprimirnumerooperacionalpreparo'], 'Sim');
    expect(mensagem['numerodopedidodestaquepreparo'], 'Sim');
    expect(produto['observacao'], 'Sem cebola');
    expect(opcoes.map((opcao) => opcao['id']), containsAll([10, 6, 7]));
    expect(jsonEncode(produto), contains('7 - (1/2) Calabresa'));
    expect(jsonEncode(produto), contains('Bordas (2)'));
    expect(jsonEncode(produto), contains('Adicionais'));
  });
  test('preparo do delivery destaca meia borda e nao imprime nao escolhida',
      () async {
    final servidor = impressao.ServidorTeste();
    Modular.init(impressao.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);

    final s = ServicoDeliveryTeste();
    final produtoCardapio = impressao.produto(
        id: '1', nome: 'Pizza', codigo: '2', computador: 'COZINHA')
      ..iditensvenda = '99';
    final bordas = impressao.bordas(['Cheddar', 'Catupiry']);
    bordas.dados!.first
      ..estaSelecionado = true
      ..somenteMetadeBorda = true;
    bordas.dados!.last.estaSelecionado = false;
    final pizzaDetalhada = impressao.produto(id: '1', nome: 'Pizza')
      ..iditensvenda = '99'
      ..opcoesPacotesListaFinal = [bordas];
    s.produtosCardapio = [produtoCardapio];
    s.atual = pedidoTeste(campos: {
      'produtos': [pizzaDetalhada.toMap()],
    });

    await ImpressaoDelivery.imprimir(s, servidor, s.atual, preparo: true);

    final mensagem = servidor.mensagens.single;
    final produto = (mensagem['produtos'] as List).single as Map;
    final json = jsonEncode(produto);

    expect(json, contains('Bordas - MEIA PIZZA (1)'));
    expect(json, contains('MEIA BORDA - (1/2) Cheddar'));
    expect(json, isNot(contains('Catupiry')));
  });
  test('comprovante do entregador imprime detalhes da pizza', () async {
    final servidor = impressao.ServidorTeste();
    final s = ServicoDeliveryTeste();
    final produtoCardapio = impressao.produto(
        id: '1', nome: 'Pizza', codigo: '2', computador: 'COZINHA')
      ..iditensvenda = '99';
    final pizzaDetalhada = impressao.produto(id: '1', nome: 'Pizza')
      ..iditensvenda = '99'
      ..observacao = 'Sem cebola'
      ..opcoesPacotesListaFinal = [
        impressao.saboresPizza(),
        impressao.bordas(['Cheddar', 'Catupiry']),
        impressao.adicionais(['Milho']),
      ];
    s.produtosCardapio = [produtoCardapio];
    s.atual = pedidoTeste(campos: {
      'produtos': [pizzaDetalhada.toMap()],
      'quantidadeprodutos': '1',
      'valorVenda': '120.00',
      'somaValorHistorico': '116.00',
      'valordaentrega': '4.00',
    });

    await ImpressaoDelivery.imprimir(s, servidor, s.atual);

    final mensagem = servidor.mensagens.single;
    final produto = (mensagem['produtos'] as List).single as Map;
    final opcoes = produto['opcoesPacotesListaFinal'] as List;

    expect(mensagem['tipoImpressao'], '3');
    expect(mensagem['nomedopc'], 'COZINHA');
    expect(produto['observacao'], 'Sem cebola');
    expect(opcoes.map((opcao) => opcao['id']), containsAll([10, 6, 7]));
    expect(jsonEncode(produto), contains('Calabresa'));
    expect(jsonEncode(produto), contains('Cheddar'));
    expect(jsonEncode(produto), contains('Catupiry'));
    expect(jsonEncode(produto), contains('Milho'));
  });
  test('atualizacao falha conserva os pedidos visiveis', () async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await p.listar();
    s.falhar = true;
    await p.listar();
    expect(p.etapas, hasLength(4));
    expect(p.erro, isNotNull);
    expect(p.carregando, isFalse);
  });
  test('pedido atualizado localmente nao volta para rascunho vazio', () async {
    final s = ServicoDeliveryTeste();
    final stale = pedidoTeste(campos: {
      'quantidadeprodutos': '0',
      'produtos': [],
      'valorVenda': '4.00',
      'valordaentrega': '4.00',
      'somaValorHistorico': '0',
    });
    final finalizado = pedidoTeste(campos: {
      'quantidadeprodutos': '7',
      'valorVenda': '114.00',
      'valordaentrega': '4.00',
      'somaValorHistorico': '114.00',
      'idVenda': '70',
      'status': 'Finalizado',
    });
    s.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': '1',
            'nomeOpcao': 'AGUARDANDO',
            'nomeBotao': 'PREPARAR',
            'tipodeimpressao': '0',
            'vendas': [stale.dados],
          }),
          ...etapasTeste().skip(1),
        ];
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await p.listar();
    expect(p.etapas.first.pedidos.single.quantidade, 0);
    p.atualizarPedido(finalizado);
    expect(p.etapas.first.pedidos.single.quantidade, 7);
    await p.listar();
    expect(p.etapas.first.pedidos.single.quantidade, 7);
    expect(p.etapas.first.pedidos.single.total, 114);
  });
  test('pedido movido localmente aparece na nova etapa antes da listagem',
      () async {
    final s = ServicoDeliveryTeste();
    final pedido = pedidoTeste();
    s.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': '1',
            'nomeOpcao': 'AGUARDANDO',
            'nomeBotao': 'PREPARAR',
            'tipodeimpressao': '0',
            'vendas': [pedido.dados],
          }),
          EtapaDelivery.fromMap({
            'id': '2',
            'nomeOpcao': 'PREPARANDO',
            'nomeBotao': 'PRONTO',
            'tipodeimpressao': '1',
            'vendas': [],
          }),
        ];
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await p.listar();

    p.moverPedidoParaEtapa(pedido, '2');

    expect(p.etapas[0].pedidos, isEmpty);
    expect(p.etapas[1].pedidos.single.id, pedido.id);
    expect(p.etapas[1].pedidos.single.etapa, '2');

    await p.listar();

    expect(p.etapas[0].pedidos, isEmpty);
    expect(p.etapas[1].pedidos.single.id, pedido.id);
  });
  test('resposta antiga de busca nao substitui a mais recente', () async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    final velha = Completer<List<EtapaDelivery>>();
    s.respostaLista = () => velha.future;
    final chamada = p.listar();
    s.respostaLista = () async => etapasTeste();
    await p.listar();
    velha.complete([]);
    await chamada;
    expect(p.etapas, hasLength(4));
    expect(p.carregando, isFalse);
  });
  test('retorno depois de fechar a tela nao notifica provedor descartado',
      () async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    final resposta = Completer<List<EtapaDelivery>>();
    s.respostaLista = () => resposta.future;
    final chamada = p.listar();
    p.dispose();
    resposta.complete(etapasTeste());
    await chamada;
  });
}
