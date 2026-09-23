import 'dart:convert';

import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/detalhes_pedido_venda.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_edicao_pedido.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_detalhes_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../essencial/utils/impressao_preparo_test.dart' as imp;
import '../../suporte/captura_tela.dart';
import 'delivery_test.dart';

Modelowordprodutos pizzaDetalhada({String item = '99'}) => imp.produto(
    id: '101', nome: 'Mussarela', computador: 'COZINHA')
  ..iditensvenda = item
  ..versaoEdicao = 'versao-$item'
  ..nomeCategoria = 'Pizza de Queijos'
  ..valorVenda = '85.00'
  ..observacao = 'Sem cebola, cortar em oito pedaços.'
  ..opcoesPacotesListaFinal = [
    ModeloOpcoesPacotes(
        id: 9,
        titulo: 'Tamanho Pizza',
        obrigatorio: false,
        dados: [ModeloDadosOpcoesPacotes(id: '2', nome: 'G', valor: '60')]),
    ModeloOpcoesPacotes(
        id: 10,
        titulo: 'Sabores Pizza (3)',
        obrigatorio: false,
        dados: [
          for (final (id, nome) in [
            ('101', 'Mussarela'),
            ('102', 'Catupiry Especial'),
            ('103', 'Dois Queijos')
          ])
            ModeloDadosOpcoesPacotes(
                id: id, nome: nome, valor: '20', quantimaximaselecao: '1/3')
        ]),
    ModeloOpcoesPacotes(id: 6, titulo: 'Bordas', obrigatorio: false, dados: [
      for (final nome in ['Cheddar', 'Goiabada'])
        ModeloDadosOpcoesPacotes(id: '4', nome: nome, valor: '6')
    ]),
    ModeloOpcoesPacotes(
        id: 7,
        titulo: 'Adicionais',
        obrigatorio: false,
        dados: [
          ModeloDadosOpcoesPacotes(
              id: '5', nome: 'Mussarela', valor: '10', quantidade: 1),
          ModeloDadosOpcoesPacotes(
              id: '6', nome: 'Milho', valor: '3', quantidade: 1)
        ]),
  ];

Modelowordprodutos almocoComAlteracoes() =>
    imp.produto(id: '436', nome: 'Almoço Livre', computador: 'COZINHA')
      ..idCategoriaCardapio = '3'
      ..opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
          id: 12,
          titulo: 'Ingredientes do Cardápio',
          tipo: 8,
          obrigatorio: false,
          dados: [
            for (final (id, nome) in [('20', 'Feijão'), ('21', 'Frango')])
              ModeloDadosOpcoesPacotes(
                id: id,
                nome: nome,
                idCategoriaCardapio: '3',
                montagemCardapio: MontagemIngredienteCardapio(
                  nomeOriginal: nome,
                  acao: AcaoIngredienteCardapio.sem,
                ),
              ),
          ],
        ),
      ];

void main() {
  setUpAll(carregarFontesDeTeste);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('prepara exibicao sem mudar o produto original nem duplicar valores',
      () {
    final original = pizzaDetalhada();
    final antes = jsonEncode(original.toMap());
    final exibicao = produtoParaDetalhesPedido(original);
    expect(exibicao.nome, 'Pizza de Queijos');
    expect(exibicao.valorVenda, '85.00');
    expect(exibicao.opcoesPacotesListaFinal![1].dados!.first.nome,
        '(1/3) Mussarela');
    expect(
        exibicao.opcoesPacotesListaFinal![1].dados!.first.quantimaximaselecao,
        isNull);
    expect(jsonEncode(original.toMap()), antes);
  });

  test('duas pizzas do mesmo produto nao trocam as montagens', () {
    final primeira = pizzaDetalhada(item: '1')..observacao = 'Primeira';
    final segunda = pizzaDetalhada(item: '2')..observacao = 'Segunda';
    final pedido = pedidoTeste(campos: {
      'produtos': [segunda.toMap(), primeira.toMap()]
    });
    final resultado = ImpressaoDelivery.produtosComDetalhesDoPedido(pedido, [
      imp.produto(id: '101')..iditensvenda = '1',
      imp.produto(id: '101')..iditensvenda = '2',
    ]);
    expect(resultado.map((p) => p.observacao), ['Primeira', 'Segunda']);
    expect(resultado.map((p) => p.versaoEdicao), ['versao-1', 'versao-2']);
  });

  test('recupera montagem local quando API antiga devolve opcoes vazias', () {
    final produtoApi =
        imp.produto(id: '436', nome: 'Almoço Livre', computador: 'COZINHA')
          ..iditensvenda = '900'
          ..valorVenda = '45.00'
          ..opcoesPacotesListaFinal = [];
    final local = almocoComAlteracoes()..valorVenda = '999.00';
    final pedido = pedidoTeste(campos: {
      'produtos': [produtoApi.toMap()]
    });

    final resultado = ImpressaoDelivery.produtosComDetalhesDoPedido(
      pedido,
      [produtoApi],
      detalhesLocais: [local],
    ).single;

    expect(resultado.valorVenda, '45.00');
    expect(resultado.destinoDeImpressao?.nomedopc, 'COZINHA');
    final ingredientes = resultado.opcoesPacotesListaFinal!.single.dados!;
    expect(ingredientes.map((item) => item.nome), ['Feijão', 'Frango']);
    expect(
      ingredientes.map((item) => item.montagemCardapio?.acao),
      everyElement(AcaoIngredienteCardapio.sem),
    );
  });

  test('preparo usa montagem local quando as duas consultas omitem detalhes',
      () async {
    final servidor = imp.ServidorTeste();
    Modular.init(imp.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final produtoApi =
        imp.produto(id: '436', nome: 'Almoço Livre', computador: 'COZINHA')
          ..iditensvenda = '900'
          ..opcoesPacotesListaFinal = [];
    final s = ServicoDeliveryTeste()
      ..produtosCardapio = [produtoApi]
      ..produtosLocais = [almocoComAlteracoes()]
      ..atual = pedidoTeste(campos: {
        'produtos': [produtoApi.toMap()]
      });

    await ImpressaoDelivery.imprimir(s, servidor, s.atual, preparo: true);

    final produto =
        ((servidor.mensagens.single['produtos'] as List).single as Map);
    expect(jsonEncode(produto), contains('Feijão'));
    expect(jsonEncode(produto), contains('Frango'));
    expect(jsonEncode(produto), contains('sem'));
  });

  test('preparo une cardapio local quando API devolve apenas adicionais', () {
    final produtoApi =
        imp.produto(id: '436', nome: 'Almoço Livre', computador: 'COZINHA')
          ..iditensvenda = '900'
          ..opcoesPacotesListaFinal = [
            imp.adicionais(['Ovo']),
          ];
    final local = almocoComAlteracoes()..iditensvenda = '900';
    final pedido = pedidoTeste(campos: {
      'produtos': [produtoApi.toMap()]
    });

    final resultado = ImpressaoDelivery.produtosComDetalhesDoPedido(
      pedido,
      [produtoApi],
      detalhesLocais: [local],
    ).single;
    final ids = resultado.opcoesPacotesListaFinal!.map((grupo) => grupo.id);
    expect(ids, containsAll(<int>[7, 12]));

    final preparo = DadosImpressaoPreparo.produto(resultado);
    final json = jsonEncode(preparo);
    expect(json, contains('SEM Feijão'));
    expect(json, contains('SEM Frango'));
    expect(json, contains('Ovo'));
  });

  test('preparo recompõe tamanho sabores bordas e adicionais da pizza', () {
    final completa = pizzaDetalhada(item: '901');
    final produtoApi = Modelowordprodutos.fromMap(completa.toMap())
      ..opcoesPacotesListaFinal = [
        completa.opcoesPacotesListaFinal![0],
      ];
    final produtoResumo = Modelowordprodutos.fromMap(completa.toMap())
      ..opcoesPacotesListaFinal = [
        completa.opcoesPacotesListaFinal![3],
      ];
    final pedido = pedidoTeste(campos: {
      'produtos': [produtoResumo.toMap()]
    });

    final resultado = ImpressaoDelivery.produtosComDetalhesDoPedido(
      pedido,
      [produtoApi],
      detalhesLocais: [completa],
    ).single;
    final grupos = resultado.opcoesPacotesListaFinal!;
    expect(grupos.map((grupo) => grupo.id).toSet(), <int>{9, 10, 6, 7});

    final preparo = jsonEncode(DadosImpressaoPreparo.produto(resultado));
    for (final detalhe in [
      'Tamanho Pizza',
      'Mussarela',
      'Catupiry Especial',
      'Dois Queijos',
      'Cheddar',
      'Goiabada',
      'Milho',
    ]) {
      expect(preparo, contains(detalhe));
    }
  });

  test('edicao envia ID do item e versao, sem alterar pagamentos', () async {
    final s = ServicoDeliveryTeste();
    final original = pizzaDetalhada();
    final alterado = Modelowordprodutos.fromMap(original.toMap())
      ..quantidade = 2;
    for (final tipo in [TipoCardapio.delivery, TipoCardapio.balcao]) {
      await ServicoEdicaoPedido(s)
          .salvarProduto(tipo, '25', original, alterado);
      final (rota, dados) = s.gravacoes.last;
      expect(rota, 'pedidos/editar.php');
      expect(dados['tipo'], tipo.nome);
      expect(dados['original']['versaoEdicao'], 'versao-99');
      expect(dados['produto']['iditensvenda'], '99');
      expect(dados['produto']['quantidade'], 2);
      expect(dados.containsKey('pagamento'), isFalse);
    }
  });

  test('reenvia preparo completo e comprovante resumido do entregador',
      () async {
    final servidor = imp.ServidorTeste();
    Modular.init(imp.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final s = ServicoDeliveryTeste()..produtosCardapio = [pizzaDetalhada()];
    final pedido = pedidoTeste(campos: {
      'produtos': [pizzaDetalhada().toMap()],
      'valorVenda': '89.00',
      'valordaentrega': '4.00',
      'somaValorHistorico': '88.00'
    });
    await ImpressaoDelivery.imprimir(s, servidor, pedido, ambos: true);
    expect(servidor.mensagens.map((m) => m['tipoImpressao']), ['1', '3']);
    final preparo = jsonEncode(servidor.mensagens.first['produtos']);
    final entregador = jsonEncode(servidor.mensagens.last['produtos']);
    for (final texto in [
      'Catupiry Especial',
      'Dois Queijos',
      'Cheddar',
      'Goiabada',
      'Milho',
      'Sem cebola'
    ]) {
      expect(preparo, contains(texto));
      expect(entregador, isNot(contains(texto)));
    }
    expect(servidor.mensagens.last['total'], '89.00');
    expect(servidor.mensagens.last['somaValorHistorico'], '88.00');
    expect(servidor.mensagens.last['valorentrega'], '4.00');
  });

  test('balcao reenvia um comprovante completo e preparo por destino',
      () async {
    final servidor = imp.ServidorTeste();
    Modular.init(imp.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final pedido = pedidoTeste(campos: {
      'tipodeentrega': '3',
      'produtos': [
        pizzaDetalhada().toMap(),
        imp.produto(computador: 'BAR').toMap()
      ],
      'valorVenda': '135'
    });
    await ServicoEdicaoPedido(ServicoDeliveryTeste()).reimprimirBalcao(
      servidor,
      pedido,
      configuracao: ModeloConfigBigchef.fromMap(
          {'imprimirpreparocomprovanteconsumacao': 'Não'}),
    );
    expect(servidor.mensagens.where((m) => m['tipoImpressao'] == '1'),
        hasLength(2));
    final comprovante =
        servidor.mensagens.singleWhere((m) => m['tipoImpressao'] == '2');
    expect(comprovante['tipo'], 'Balcão');
    expect(comprovante['produtos'], hasLength(2));
    expect(comprovante['total'], '135.00');
  });

  test('balcao incorpora preparo no comprovante quando configurado', () async {
    final servidor = imp.ServidorTeste();
    Modular.init(imp.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final pedido = pedidoTeste(campos: {
      'tipodeentrega': '3',
      'produtos': [pizzaDetalhada().toMap()],
      'valorVenda': '85'
    });

    await ServicoEdicaoPedido(ServicoDeliveryTeste()).reimprimirBalcao(
      servidor,
      pedido,
      configuracao: ModeloConfigBigchef.fromMap(
          {'imprimirpreparocomprovanteconsumacao': 'Sim'}),
    );

    expect(servidor.mensagens, hasLength(1));
    expect(servidor.mensagens.single['tipoImpressao'], '2');
    expect(jsonEncode(servidor.mensagens.single['produtos']),
        contains('Catupiry Especial'));
  });

  test('balcao mantem preparo avulso quando essa foi a unica opcao escolhida',
      () async {
    final servidor = imp.ServidorTeste();
    Modular.init(imp.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final pedido = pedidoTeste(campos: {
      'tipodeentrega': '3',
      'produtos': [pizzaDetalhada().toMap()],
    });

    await ServicoEdicaoPedido(ServicoDeliveryTeste()).reimprimirBalcao(
      servidor,
      pedido,
      preparo: true,
      comprovante: false,
      configuracao: ModeloConfigBigchef.fromMap(
          {'imprimirpreparocomprovanteconsumacao': 'Sim'}),
    );

    expect(servidor.mensagens, hasLength(1));
    expect(servidor.mensagens.single['tipoImpressao'], '1');
  });

  testWidgets('detalhes normais do delivery oferecem edicao e opcoes da pizza',
      (tester) async {
    final s = ServicoDeliveryTeste();
    s.atual = pedidoTeste(campos: {
      'produtos': [pizzaDetalhada().toMap()],
      'idVenda': '100'
    });
    s.produtosCardapio = [imp.produto(id: '101')..iditensvenda = '99'];
    await tester.pumpWidget(
        MaterialApp(home: PaginaDetalhesDelivery(servico: s, id: '25')));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Editar pedido'), findsOneWidget);
    expect(find.text('Editar Produto'), findsOneWidget);
    expect(
        find.text(
            '(1/3) Mussarela\n(1/3) Catupiry Especial\n(1/3) Dois Queijos'),
        findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Ver detalhes'));
    await tester.tap(find.byTooltip('Ver detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('(1/3) Catupiry Especial'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final (largura, altura, escala) in [
    (430.0, 932.0, 1.0),
    (820.0, 1180.0, 1.0),
    (320.0, 568.0, 1.6)
  ]) {
    testWidgets(
        'detalhes recolhidos e expandidos sem sobreposicao $largura/$escala',
        (tester) async {
      tester.view.physicalSize = Size(largura, altura);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Modelowordprodutos? editado;
      final produto = pizzaDetalhada();
      await tester.pumpWidget(MaterialApp(
          theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
          builder: (_, child) => MediaQuery(
              data: MediaQueryData(
                  size: Size(largura, altura),
                  textScaler: TextScaler.linear(escala)),
              child: child!),
          home: RepaintBoundary(
              key: const ValueKey('captura'),
              child: Scaffold(
                  appBar: AppBar(title: const Text('Detalhes do Delivery')),
                  bottomNavigationBar: const RodapeTotalPedidoVenda(total: 89),
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: DetalhesPedidoVenda(
                          tipo: TipoCardapio.delivery,
                          numero: '123',
                          cliente: 'Bruno Masson',
                          telefone: '(44) 99921-3336',
                          modalidade: 'Entrega',
                          endereco:
                              'Rua Luiz Roncalha, 169, Jardim Italia, Santa Fe',
                          produtos: [produto],
                          total: 89,
                          recebido: 88,
                          entrega: 4,
                          editarPedido: () {},
                          editarProduto: (p) => editado = p))))));
      await tester.pumpAndSettle();
      expect(find.text('(1/3) Mussarela').hitTestable(), findsNothing);
      await capturarTela(tester, 'detalhes_pedido_${largura}_fechado');
      await tester.ensureVisible(find.byTooltip('Ver detalhes'));
      await tester.tap(find.byTooltip('Ver detalhes'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Sabores Pizza (3)'));
      await tester.pumpAndSettle();
      expect(find.text('(1/3) Mussarela').hitTestable(), findsOneWidget);
      await capturarTela(tester, 'detalhes_pedido_${largura}_aberto');
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Editar Produto'));
      await tester.tap(find.text('Editar Produto'));
      expect(identical(editado, produto), isTrue);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('editar dados salva sem criar outro pedido ou abrir cardapio',
      (tester) async {
    Map<String, dynamic>? dados;
    bool? retornou;
    final s = ServicoDeliveryTeste();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () async {
                      retornou = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                              builder: (_) => PaginaNovoDelivery(
                                  servico: s,
                                  editarPedido: pedidoTeste(campos: {
                                    'tipodeentrega': '3',
                                    'idCliente': '0'
                                  }),
                                  permitirEntrega: false,
                                  aoSalvarEdicao: (valor) async {
                                    dados = valor;
                                  })));
                    },
                    child: const Text('Abrir edição'))))));
    await tester.tap(find.text('Abrir edição'));
    await tester.pumpAndSettle();
    expect(find.text('Entrega'), findsNothing);
    await tester.enterText(find.byType(TextField).last, 'Retirar sem talheres');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(dados!['observacao'], 'Retirar sem talheres');
    expect(dados!['tipoentrega'], '3');
    expect(dados!['taxa'], '0.00');
    expect(s.gravacoes, isEmpty);
    expect(retornou, isTrue);
    expect(find.text('Abrir edição'), findsOneWidget);
  });
}
