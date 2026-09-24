import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/gerador_cardapio_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
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
  @override
  Future<PagamentoRecorrente?> pagamentoRecorrente(String id) async => null;
  ServicoDeliveryTeste()
      : super(
            DioFalso(),
            UsuarioProvedor()
              ..setUsuario(
                  UsuarioModelo(id: '2', empresa: '3', nome: 'Operador')));
  final gravacoes = <(String, Map<String, dynamic>)>[];
  final notificacoes = <({
    MensagemClienteDelivery mensagem,
    String cliente,
    String endereco,
    String idDelivery,
    String valorPedido,
  })>[];
  int cardapiosEnviados = 0;
  PedidoDelivery atual = pedidoTeste();
  bool falhar = false;
  int consultas = 0;
  ConfigDelivery config =
      const ConfigDelivery(receberNoFinal: true, imprimirPreparo: false);
  List<Modelowordprodutos> produtosCardapio = [];
  List<Modelowordprodutos> produtosLocais = [];
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
  Future<List<Modelowordprodutos>> detalhesLocais(String id) async =>
      [...produtosLocais];
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

  @override
  Future<String> notificarCliente(
    MensagemClienteDelivery mensagem, {
    String cliente = '0',
    String endereco = '0',
    String idDelivery = '0',
    String valorPedido = '',
  }) async {
    notificacoes.add((
      mensagem: mensagem,
      cliente: cliente,
      endereco: endereco,
      idDelivery: idDelivery,
      valorPedido: valorPedido,
    ));
    return 'Enviado com sucesso!';
  }

  @override
  Future<String> enviarCardapioDoDia({
    String cliente = '0',
    String idDelivery = '0',
  }) async {
    cardapiosEnviados++;
    return 'Cardápio enviado com sucesso!';
  }
}

class AdaptadorDelivery extends Fake implements HttpClientAdapter {
  AdaptadorDelivery([
    this.resposta = '{"sucesso":true,"dados":[]}',
  ]);

  final String resposta;
  final chamadas = <RequestOptions>[];
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    return ResponseBody.fromString(resposta, 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

class ServicoRascunhoMensagem extends ServicoDelivery {
  ServicoRascunhoMensagem(super.dio, super.usuario);
  @override
  Future<PedidoDelivery> pedido(String id) async => pedidoTeste(campos: {
        'id': id,
        'idCliente': '4',
        'idendereco': '17',
      });
}

class ServicoGeracaoCardapioTeste extends ServicoDelivery {
  ServicoGeracaoCardapioTeste(super.dio, super.usuario);

  int consultasCardapio = 0;
  int uploads = 0;

  @override
  Future<DadosCardapioDelivery> cardapioDoDia() async {
    consultasCardapio++;
    return DadosCardapioDelivery(
      ingredientes: const ['Arroz', 'Feijão'],
      produtos: const [
        ProdutoCardapioDelivery(nome: 'Marmita M', valor: 30),
      ],
    );
  }

  @override
  Future<String> enviarImagemCardapio(
    Uint8List imagem, {
    String cliente = '0',
    String idDelivery = '0',
  }) async {
    uploads++;
    return 'Cardápio criado e enviado!';
  }
}

void main() {
  test('gera o cardapio do dia como imagem PNG', () async {
    final bytes = await GeradorCardapioDelivery.gerar(
      nomeEmpresa: 'Restaurante Teste',
      ingredientes: const ['Arroz', 'Feijão', 'Carne de Panela'],
      produtos: const [
        ProdutoCardapioDelivery(nome: 'Marmita P', valor: 20),
        ProdutoCardapioDelivery(nome: 'Marmita M', valor: 30),
        ProdutoCardapioDelivery(nome: 'Marmita G', valor: 45),
      ],
      data: DateTime(2026, 9, 24),
    );

    expect(bytes.length, greaterThan(1000));
    expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
  });

  test('carrega produtos marcados para o cardapio com nome e valor', () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'})
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery(
      '{"sucesso":true,"ingredientes":[{"nome":"Arroz"}],'
      '"produtos":[{"nome":"Marmita M","valor":30.5}]}',
    );
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '3'));
    addTearDown(usuario.dispose);

    final cardapio = await ServicoDelivery(dio, usuario).cardapioDoDia();

    expect(cardapio.ingredientes, ['Arroz']);
    expect(cardapio.produtos.single.nome, 'Marmita M');
    expect(cardapio.produtos.single.valor, 30.5);
    expect(cardapio.produtos.single.valorFormatado, contains('30,50'));
  });

  test('configuracao geral interpreta a unificacao do preparo', () {
    final config = ModeloConfigBigchef.fromMap({
      'imprimir_preparo_comprovante_consumacao': 'Sim',
    });

    expect(config.imprimePreparoNoComprovanteConsumacao, isTrue);
    expect(config.toMap()['imprimirpreparocomprovanteconsumacao'], 'Sim');
  });

  TestWidgetsFlutterBinding.ensureInitialized();
  test('periodo dos pedidos locais acompanha o dia operacional da API', () {
    final madrugada = periodoOperacionalDelivery(
        inicio: DateTime(2026, 9, 23),
        fim: DateTime(2026, 9, 23),
        horaInicio: '05:00:00',
        horaFim: '05:00:00',
        agora: DateTime(2026, 9, 23, 2));
    expect(madrugada.inicio, DateTime(2026, 9, 22, 5));
    expect(madrugada.fim, DateTime(2026, 9, 23, 5));
    final noite = periodoOperacionalDelivery(
        inicio: DateTime(2026, 9, 23),
        fim: DateTime(2026, 9, 23),
        horaInicio: '05:00:00',
        horaFim: '05:00:00',
        agora: DateTime(2026, 9, 23, 22));
    expect(noite.inicio, DateTime(2026, 9, 23, 5));
    expect(noite.fim, DateTime(2026, 9, 24, 5));
  });

  test('mensagem de pagamento usa cliente do rascunho sem criar pedido remoto',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'}),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery();
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '3'));
    addTearDown(usuario.dispose);
    await ServicoRascunhoMensagem(dio, usuario).notificarCliente(
        MensagemClienteDelivery.formaPagamento,
        idDelivery: 'delivery-local:teste');
    final chamada = adapter.chamadas.single;
    expect(chamada.path, 'delivery/notificar_cliente.php');
    final dados = jsonDecode(chamada.data as String) as Map;
    expect(dados['cliente'], '4');
    expect(dados['endereco'], '17');
    expect(dados['id_delivery'], '0');
    expect(dados['acao'], 'forma');
  });
  test('imagem do cardapio usa upload multipart no servidor do Delivery',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'}),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery();
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '3'));
    addTearDown(usuario.dispose);

    await ServicoDelivery(dio, usuario).enviarImagemCardapio(
      Uint8List.fromList([137, 80, 78, 71]),
      cliente: '4',
    );

    final chamada = adapter.chamadas.single;
    expect(chamada.path, 'delivery/notificar_cliente.php');
    final formulario = chamada.data as FormData;
    expect(Map.fromEntries(formulario.fields)['acao'], 'cardapio');
    expect(Map.fromEntries(formulario.fields)['cliente'], '4');
    expect(formulario.files.single.key, 'arquivo');
    expect(formulario.files.single.value.filename, 'cardapio-do-dia.png');
  });
  test('cardapio online existente e reutilizado sem gerar outra imagem',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'}),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery(
      '{"sucesso":true,"mensagem":"Cardápio enviado do cache!"}',
    );
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
        id: '2',
        empresa: '3',
        nomeEmpresa: 'Restaurante Teste',
      ));
    addTearDown(usuario.dispose);
    final servico = ServicoGeracaoCardapioTeste(dio, usuario);

    final mensagem = await servico.enviarCardapioDoDia(cliente: '4');

    expect(mensagem, 'Cardápio enviado do cache!');
    expect(servico.consultasCardapio, 0);
    expect(servico.uploads, 0);
    expect(adapter.chamadas, hasLength(1));
  });
  test('cardapio e gerado somente quando o servidor online solicita a imagem',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'}),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery(
      '{"sucesso":false,"precisa_imagem":true}',
    );
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
        id: '2',
        empresa: '3',
        nomeEmpresa: 'Restaurante Teste',
      ));
    addTearDown(usuario.dispose);
    final servico = ServicoGeracaoCardapioTeste(dio, usuario);

    final mensagem = await servico.enviarCardapioDoDia(cliente: '4');

    expect(mensagem, 'Cardápio criado e enviado!');
    expect(servico.consultasCardapio, 1);
    expect(servico.uploads, 1);
  });
  test('confirmacao do rascunho local usa cliente e omite numero do pedido',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'}),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery();
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '3'));
    addTearDown(usuario.dispose);
    final produto = impressao.produto(nome: 'Pizza')
      ..valorVenda = '84'
      ..quantidade = 1;
    final pedido = PedidoDelivery.fromMap({
      'id': 'delivery-local:teste',
      'idCliente': '4',
      'celularCliente': '(44) 99999-9999',
      'idendereco': '17',
      'tipodeentrega': '1',
      'valordaentrega': '4.00',
      'valorVenda': '88.00',
      'produtos': [produto.toMap()],
    });

    await ServicoRascunhoMensagem(dio, usuario)
        .notificarConfirmacaoPedido(pedido);

    final chamada = adapter.chamadas.single;
    expect(chamada.path, 'delivery/notificar_cliente.php');
    final dados = jsonDecode(chamada.data as String) as Map;
    expect(dados['acao'], 'confirmar');
    expect(dados['cliente'], '4');
    expect(dados['endereco'], '17');
    expect(dados['id_delivery'], '0');
    expect(dados['pedidoLocal'], isTrue);
    expect(dados['tipoEntrega'], '1');
    expect(dados['produtos'], hasLength(1));
    expect(dados['valorPedido'], '84.00');
    expect(dados['valorEntrega'], '4.00');
    expect(dados['valorTotalPedido'], '88.00');
    expect(dados['formaPagamento'], 'A definir');
    expect(dados.containsKey('id'), isFalse);
  });
  test('confirmacao local sem celular nao chama o servidor', () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': '127.0.0.1', 'porta': '8080'}),
    });
    final dio = DioCliente();
    final adapter = AdaptadorDelivery();
    dio.cliente.httpClientAdapter = adapter;
    addTearDown(() => dio.cliente.close());
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '2', empresa: '3'));
    addTearDown(usuario.dispose);
    final pedido = PedidoDelivery.fromMap({
      'id': 'delivery-local:sem-celular',
      'idCliente': '4',
      'celularCliente': 'Sem Celular',
      'idendereco': '17',
      'tipodeentrega': '1',
      'valordaentrega': '4.00',
      'valorVenda': '54.00',
      'produtos': [impressao.produto().toMap()],
    });

    await expectLater(
      ServicoRascunhoMensagem(dio, usuario).notificarConfirmacaoPedido(pedido),
      throwsA(isA<StateError>()
          .having((erro) => erro.message, 'mensagem', contains('sem celular'))),
    );
    expect(adapter.chamadas, isEmpty);
  });
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
      'obrigarjustifcancelarpedido': 'Sim',
      'formacobrancaentregadelivery': '2',
      'valordiferenca': '2.50',
      'entregadorfixo': '1',
      'identregador': '0',
      'imprimirpreparocomprovanteconsumacao': 'Sim',
    });
    expect(config.exigePagamento(pedidoTeste(), etapasTeste()[1]), isFalse);
    expect(config.motivoCancelamentoObrigatorio, isTrue);
    expect(config.exigePagamento(pedidoTeste(), etapasTeste().last), isTrue);
    expect(config.taxaEntrega('6.00'), 8.5);
    expect(config.entregadorFixo, isEmpty);
    expect(config.imprimirPreparoNoComprovanteConsumacao, isTrue);
    expect(config.imprimirPreparoSeparado, isFalse);
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
  test('modelos e rascunhos nunca aparecem no carrossel do Delivery', () {
    final etapa = EtapaDelivery.fromMap({
      'id': '1',
      'vendas': [
        {'id': '10', 'status': ' Modelo Recorrente '},
        {'id': '12', 'status': ' Rascunho Aplicativo '},
        {'id': '11', 'status': 'Pendente'},
      ],
    });

    expect(etapa.pedidos.map((pedido) => pedido.id), ['11']);
  });
  test('regra de entregador da etapa aceita variacoes da API', () {
    for (final valor in ['Sim', ' sim ', 'TRUE', '1']) {
      final etapa = EtapaDelivery.fromMap({
        'id': '1',
        'ativarselecaoentregador': valor,
      });
      expect(etapa.selecionarEntregador, isTrue, reason: valor);
    }
    expect(
        EtapaDelivery.fromMap({
          'id': '1',
          'ativarselecaoentregador': 'Não',
        }).selecionarEntregador,
        isFalse);
  });
  test('mensagem de cliente usa a rota do Delivery sem alterar pagamento',
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

    await servico.notificarCliente(
      MensagemClienteDelivery.formaPagamento,
      idDelivery: '25',
    );

    final requisicao = adapter.chamadas.single;
    expect(requisicao.uri.path, endsWith('/delivery/notificar_cliente.php'));
    expect(requisicao.uri.path, contains('/api_restaurantes_venda/'));
    final dados = jsonDecode(requisicao.data as String) as Map;
    expect(dados['acao'], 'forma');
    expect(dados['id_delivery'], '25');
    expect(dados['empresa'], '3');
    expect(dados['id_usuario'], '2');
  });
  test('pergunta de troco envia a acao e o valor total do pedido', () async {
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

    await servico.notificarCliente(
      MensagemClienteDelivery.perguntarTroco,
      idDelivery: '25',
      valorPedido: '76.00',
    );

    final requisicao = adapter.chamadas.single;
    final dados = jsonDecode(requisicao.data as String) as Map;
    expect(dados['acao'], 'troco');
    expect(dados['id_delivery'], '25');
    expect(dados['valor_pedido'], '76.00');
  });
  test('confirmacao do pedido reutiliza os dados da acao do menu', () async {
    final servico = ServicoDeliveryTeste();
    servico.produtosCardapio = [impressao.produto()];
    final pedido = pedidoTeste(campos: {
      'idendereco': '17',
      'valordaentrega': '6.00',
    });

    await servico.notificarConfirmacaoPedido(pedido);

    final gravacao = servico.gravacoes.single;
    expect(gravacao.$1, 'delivery/acoes_pedido.php');
    expect(gravacao.$2['acao'], 'confirmar');
    expect(gravacao.$2['id'], '25');
    expect(gravacao.$2['id_cliente'], '4');
    expect(gravacao.$2['idEndereco'], '17');
    expect(gravacao.$2['produtos'], hasLength(1));
    expect(gravacao.$2['valorPedido'], '80.00');
    expect(gravacao.$2['valorEntrega'], '6.00');
    expect(gravacao.$2['valorTotalPedido'], '86.00');
    expect(gravacao.$2['formaPagamento'], 'A definir');
  });
  test('confirmacao omite ingredientes normais e envia forma de pagamento',
      () async {
    final servico = ServicoDeliveryTeste();
    final marmita = impressao.produto(nome: 'Marmita M')
      ..opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
          id: 12,
          titulo: 'Ingredientes do Cardápio',
          tipo: 8,
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: '1',
              nome: 'Arroz',
              montagemCardapio: const MontagemIngredienteCardapio(
                nomeOriginal: 'Arroz',
                acao: AcaoIngredienteCardapio.pouco,
              ),
            ),
            ModeloDadosOpcoesPacotes(
              id: '2',
              nome: 'Feijão',
              montagemCardapio: const MontagemIngredienteCardapio(
                nomeOriginal: 'Feijão',
              ),
            ),
          ],
        ),
      ];
    servico.produtosCardapio = [marmita];

    await servico.notificarConfirmacaoPedido(
      pedidoTeste(campos: {'idendereco': '17'}),
      formaPagamento: 'Pix',
    );

    final campos = servico.gravacoes.single.$2;
    final produto = (campos['produtos'] as List).single as Map;
    final grupo = (produto['opcoesPacotesListaFinal'] as List).single as Map;
    final ingredientes = grupo['dados'] as List;
    expect(ingredientes.map((item) => (item as Map)['nome']), ['POUCO Arroz']);
    expect(campos['formaPagamento'], 'Pix');
  });
  test('lista permite copia offline isolada pela empresa e pelo usuario',
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
    expect(r.uri.path, endsWith('/delivery/listar_opcoes.php'));
    expect(r.uri.path, contains('/api_restaurantes_venda/'));
    expect(r.queryParameters['empresa'], '3');
    expect(r.queryParameters['id_usuario'], '2');
    expect(r.extra['semCache'], isFalse);
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
  test('preserva detalhes do delivery no armazenamento local', () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'local',
        'servidor': '192.168.2.109',
        'porta': '9980',
      }),
    });
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '275', empresa: '32'));
    final servico = ServicoDelivery(DioFalso(), usuario);
    final produto = impressao.produto(id: '436', nome: 'Almoço Livre')
      ..idCategoriaCardapio = '3'
      ..opcoesPacotesListaFinal = [
        impressao.bordas(['Feijão'])
      ];

    await servico.registrarDetalhesLocais('150', [produto]);
    final recuperados = await servico.detalhesLocais('150');

    expect(recuperados, hasLength(1));
    expect(recuperados.single.idCategoriaCardapio, '3');
    expect(
        recuperados.single.opcoesPacotesListaFinal!.single.dados!.single.nome,
        'Feijão');
  });
  test('comprovante preserva o endereco escolhido no pedido', () {
    final s = ServicoDeliveryTeste();
    final pedido = pedidoTeste(campos: {
      'nomeCliente': '  Bruno Masson  ',
      'enderecoCliente': 'Rua selecionada',
      'numeroCliente': '133',
      'complementoCliente': 'Fundos',
      'bairroCliente': 'Centro',
      'cidadeCliente': 'Lobato',
    }).comEndereco(Modeloworddadoscardapio(
        enderecoCliente: 'Rua padrao incorreta',
        numeroCliente: '169',
        complementoCliente: 'Complemento padrao incorreto',
        bairroCliente: 'Jardim Italia'));
    final mensagens = ImpressaoDelivery.comprovantes(s, pedido, [
      impressao.produto(computador: 'CAIXA'),
      impressao.produto(computador: 'COZINHA')
    ]);
    expect(mensagens, hasLength(2));
    final json = jsonDecode(mensagens.first) as Map;
    expect(json['tipo'], 'Delivery');
    expect(json['tipoImpressao'], '3');
    expect(json['nomeCliente'], 'Bruno Masson');
    expect(json['enderecoCliente'], 'Rua selecionada');
    expect(json['numeroCliente'], '133');
    expect(json['complementoCliente'], 'Fundos');
    expect(json['bairroCliente'], 'Centro');
    expect(json['cidadeCliente'], 'Lobato');
    expect(json['nomedopc'], 'CAIXA');
    expect(json['numeroPedido'], '14');
    expect(json['comanda'], 'Delivery 25');
    expect(json['protocoloImpressao'], 2);
  });
  test('mantem numero e bairro separados para o layout do comprovante', () {
    final pedido = pedidoTeste(campos: {
      'enderecoCliente': '  Rua Sem Saida  ',
      'numeroCliente': ' 133 ',
      'bairroCliente': ' Centro ',
      'complementoCliente': ' Fundos ',
      'cidadeCliente': ' Lobato ',
    });

    expect(ImpressaoDelivery.camposEnderecoComprovante(pedido), {
      'enderecoCliente': 'Rua Sem Saida',
      'numeroCliente': '133',
      'bairroCliente': 'Centro',
      'cidadeCliente': 'Lobato',
      'complementoCliente': 'Fundos',
    });
  });
  test('comprovante aceita endereco do cardapio como fallback', () {
    final pedido = pedidoTeste(campos: {
      'enderecoCliente': '',
      'numeroCliente': '',
      'bairroCliente': '',
    }).comEndereco(Modeloworddadoscardapio(
        enderecoCliente: 'Rua da API antiga',
        numeroCliente: '5',
        bairroCliente: 'Centro'));

    expect(pedido.texto('enderecoCliente'), 'Rua da API antiga');
    expect(pedido.texto('numeroCliente'), '5');
    expect(pedido.texto('bairroCliente'), 'Centro');
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
  test('comprovante do entregador preserva detalhes quando unifica preparo',
      () {
    final s = ServicoDeliveryTeste();
    final produto = Modelowordprodutos.fromMap({
      ...impressao.produto(computador: 'CAIXA').toMap(),
      'observacao': 'Sem cebola',
      'opcoesPacotesListaFinal': [
        {
          'id': 7,
          'titulo': 'Adicionais',
          'dados': [
            {'id': '8', 'nome': 'Ovo', 'valor': '2', 'quantidade': 1}
          ],
        }
      ],
    });

    final resumo = jsonDecode(ImpressaoDelivery.comprovantes(
      s,
      pedidoTeste(),
      [produto],
      config: const ConfigDelivery(
        imprimirPreparoNoComprovanteConsumacao: false,
      ),
    ).single) as Map<String, dynamic>;
    final unificado = jsonDecode(ImpressaoDelivery.comprovantes(
      s,
      pedidoTeste(),
      [produto],
      config: const ConfigDelivery(
        imprimirPreparoNoComprovanteConsumacao: true,
      ),
    ).single) as Map<String, dynamic>;

    expect(
        (resumo['produtos'] as List).single['opcoesPacotesListaFinal'], isNull);
    expect(
      (unificado['produtos'] as List).single['opcoesPacotesListaFinal'],
      isNotEmpty,
    );
    expect((unificado['produtos'] as List).single['observacao'], 'Sem cebola');
  });
  test('preserva detalhes se a configuracao local nao estiver disponivel', () {
    final s = ServicoDeliveryTeste();
    final produto = Modelowordprodutos.fromMap({
      ...impressao.produto(computador: 'CAIXA').toMap(),
      'observacao': 'Sem cebola',
      'opcoesPacotesListaFinal': [
        {
          'id': 7,
          'titulo': 'Adicionais',
          'dados': [
            {'id': '8', 'nome': 'Ovo', 'valor': '2', 'quantidade': 1}
          ],
        }
      ],
    });

    final mensagem = jsonDecode(ImpressaoDelivery.comprovantes(
      s,
      pedidoTeste(),
      [produto],
    ).single) as Map<String, dynamic>;

    expect(
      (mensagem['produtos'] as List).single['opcoesPacotesListaFinal'],
      isNotEmpty,
    );
    expect((mensagem['produtos'] as List).single['observacao'], 'Sem cebola');
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
  test('comprovante resumido preserva somente os sabores da pizza', () async {
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
    expect(mensagem['tipoImpressao'], '3');
    expect(mensagem['nomedopc'], 'COZINHA');
    expect(mensagem['enderecoCliente'], 'Rua das Flores');
    expect(mensagem['numeroCliente'], '123');
    expect(produto['nome'], 'Pizza');
    expect(produto['observacao'], isNull);
    expect(produto['ingredientes'], isEmpty);
    expect(produto['opcoesPacotes'], isNull);
    final opcoes = produto['opcoesPacotesListaFinal'] as List;
    expect(opcoes, hasLength(1));
    expect(opcoes.single['id'], 10);
    expect(
      (opcoes.single['dados'] as List).map((sabor) => sabor['nome']),
      ['Calabresa', 'Chocolate'],
    );
    for (final detalhe in ['Sem cebola', 'Cheddar', 'Catupiry', 'Milho']) {
      expect(jsonEncode(produto), isNot(contains(detalhe)));
    }
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
  test('pedido removido localmente nao reaparece se a atualizacao falhar',
      () async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await p.listar();
    final id = p.etapas.first.pedidos.first.id;

    p.removerPedido(id);
    expect(p.etapas.expand((etapa) => etapa.pedidos).map((pedido) => pedido.id),
        isNot(contains(id)));

    s.falhar = true;
    await p.listar();
    expect(p.etapas.expand((etapa) => etapa.pedidos).map((pedido) => pedido.id),
        isNot(contains(id)));
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
    final nova = p.listar();
    expect(s.consultas, 1);
    velha.complete([]);
    await Future.wait([chamada, nova]);
    expect(s.consultas, 2);
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
