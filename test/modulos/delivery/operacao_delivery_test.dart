import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/alterar_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/busca_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/endereco_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../essencial/utils/impressao_preparo_test.dart' as impressao;
import '../../suporte/captura_tela.dart';
import 'delivery_test.dart';

class ServicoCancelamentoTeste extends ServicoDeliveryTeste {
  @override
  Future<Map<String, dynamic>> acao(String acao, PedidoDelivery pedido,
      [Map<String, dynamic> campos = const {}]) async {
    if (acao == 'cancelar' && campos['senha'] != 'senha-teste') {
      throw StateError('Senha Admin de cancelamento incorreta.');
    }
    return super.acao(acao, pedido, campos);
  }
}

class ServicoEnderecoPadraoTeste extends ServicoDeliveryTeste {
  final List<Map<String, dynamic>> enderecos;
  final String requeridoEndereco;
  ServicoEnderecoPadraoTeste(this.enderecos, {this.requeridoEndereco = 'Sim'});

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'enderecos_clientes/listar_por_cliente.php') {
      return enderecos;
    }
    if (rota == 'config_clientes/listar_cliente.php') {
      final resposta = await super.consultar(rota, campos);
      return {
        if (resposta is Map) ...Map<String, dynamic>.from(resposta),
        'requerido_endereco': requeridoEndereco,
      };
    }
    return super.consultar(rota, campos);
  }
}

class ServicoNovoEnderecoTeste extends ServicoEnderecoPadraoTeste {
  ServicoNovoEnderecoTeste(super.enderecos);

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final resposta = await super.salvar(rota, campos);
    if (rota == 'clientes/inserir_endereco.php' && campos['id'] == '') {
      enderecos.add({
        'id': '11',
        'cep': campos['cep'],
        'endereco': campos['endereco'],
        'numero': campos['numero'],
        'bairro': campos['bairro'],
        'cidade': campos['cidade'],
        'estado': campos['uf'],
        'complemento': campos['complemento'],
        'padrao': campos['padrao'],
      });
    }
    return resposta;
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  test('pagamento nao encerra preparo nem remove taxa da entrega', () {
    final pago = pedidoTeste(campos: {
      'idVenda': '70',
      'status': 'Finalizado',
      'valordaentrega': '4'
    });
    expect(pago.encerrado, isTrue);
    expect(pago.podeAvancar(etapasTeste().first), isTrue);
    expect(pago.podeAvancar(etapasTeste().last), isFalse);
    expect(pago.taxaEntrega, 4);
    expect(
        pedidoTeste(campos: {'status': 'Cancelado'})
            .podeAvancar(etapasTeste().first),
        isFalse);
    expect(
        pedidoTeste(campos: {'tipodeentrega': '2', 'valordaentrega': '4'})
            .taxaEntrega,
        0);
  });

  test('clone nao reutiliza identificadores ou modifica produtos originais',
      () async {
    SharedPreferences.setMockInitialValues({});
    final original = impressao.produto()
      ..iditensvenda = '80'
      ..hashprodutos = 'hash-original'
      ..novo = false;
    final s = ServicoDeliveryTeste();
    await s.prepararClone('26', [original]);
    final itens = await ArmazenamentoCarrinhos.instancia.listar(
        const ContextoCarrinho(
            empresa: '3', tipo: 'delivery', idAtendimento: '26'));
    expect(itens, hasLength(1));
    expect(itens.single.iditensvenda, anyOf(isNull, isEmpty));
    expect(itens.single.hashprodutos, anyOf(isNull, isEmpty));
    expect(itens.single.novo, isTrue);
    expect(original.iditensvenda, '80');
    await expectLater(s.prepararClone('26', [original]), throwsStateError);
  });

  test('recebimento rapido conserva acrescimo e desconto do pedido', () async {
    final s = ServicoDeliveryTeste();
    await s.pagar(
        pedidoTeste(campos: {'valorDesconto': '3', 'valorAcrescimo': '2'}),
        5,
        86);
    expect(s.gravacoes.single.$2['valordesconto'], '3.00');
    expect(s.gravacoes.single.$2['valoracrescimo'], '2.00');
  });

  testWidgets('pedido pago mostra PREPARAR e nao cobra nem conclui novamente',
      (tester) async {
    final s = ServicoDeliveryTeste()
      ..config = const ConfigDelivery(imprimirPreparo: false);
    s.atual = pedidoTeste(campos: {
      'id': '1',
      'idVenda': '70',
      'status': 'Finalizado',
      'somaValorHistorico': '86',
      'valordaentrega': '4'
    });
    final lista = [
      EtapaDelivery.fromMap({
        'id': '1',
        'nomeOpcao': 'AGUARDANDO',
        'nomeBotao': 'PREPARAR',
        'tipodeimpressao': '0',
        'vendas': [s.atual.dados]
      }),
      ...etapasTeste().skip(1)
    ];
    s.respostaLista = () async => lista;
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();
    expect(find.text('PREPARAR'), findsOneWidget);
    expect(find.text('Concluído'), findsNothing);
    expect(tester.widget<Text>(find.textContaining('Entrega:')).data,
        contains('4,00'));
    await tester.tap(find.text('PREPARAR'));
    await tester.tap(find.text('PREPARAR'));
    await tester.pumpAndSettle();
    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$1, 'delivery/mudar_status_delivery.php');
    expect(s.gravacoes.single.$2['valor_da_entrega'], '4');
    expect(s.gravacoes.single.$2['statusOrigem'], '1');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('card do delivery mostra previa de itens somente ao expandir',
      (tester) async {
    final s = ServicoDeliveryTeste();
    final pizza = impressao.produto(id: '1', nome: 'Pizza', codigo: '2')
      ..quantidade = 1
      ..valorTotalVendas = '86.00'
      ..observacao = 'Sem cebola'
      ..opcoesPacotesListaFinal = [
        impressao.saboresPizza(),
        impressao.bordas(['Cheddar']),
        impressao.adicionais(['Milho']),
      ];
    final pedido = pedidoTeste(campos: {
      'quantidadeprodutos': '1',
      'valorVenda': '90.00',
      'valordaentrega': '4.00',
      'produtos': [pizza.toMap()],
    });
    s.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': '1',
            'nomeOpcao': 'AGUARDANDO',
            'nomeBotao': 'PREPARAR',
            'tipodeimpressao': '0',
            'vendas': [pedido.dados],
          }),
          ...etapasTeste().skip(1),
        ];
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);

    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();

    expect(find.text('Ver itens (1 item)'), findsOneWidget);
    expect(find.text('Ocultar itens'), findsNothing);

    await tester.tap(find.text('Ver itens (1 item)'));
    await tester.pumpAndSettle();

    expect(find.text('Ocultar itens'), findsOneWidget);
    expect(find.text('Pizza'), findsOneWidget);
    expect(find.textContaining('Calabresa'), findsOneWidget);
    expect(find.textContaining('Cheddar'), findsOneWidget);
    expect(find.textContaining('Milho'), findsOneWidget);
    expect(find.text('Obs: Sem cebola'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('deslizar muda a aba e atualizar conserva a etapa selecionada',
      (tester) async {
    final s = ServicoDeliveryTeste();
    final p = ProvedorDelivery(s);
    addTearDown(p.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(TabBarView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    await p.listar();
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 1);
    s.respostaLista = () async => etapasTeste().skip(1).toList();
    await p.listar();
    await tester.pumpAndSettle();
    expect(tester.widget<TabBar>(find.byType(TabBar)).controller!.index, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pix envia o codigo 5 esperado pela API, nao credito',
      (tester) async {
    final s = ServicoDeliveryTeste();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => receberDelivery(context, s, '25'),
                    child: const Text('Receber'))))));
    await tester.tap(find.text('Receber'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pix').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(s.gravacoes.single.$2['pagamentoSelecionado'], 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('senha invalida conserva modal e senha correta cancela uma vez',
      (tester) async {
    final s = ServicoCancelamentoTeste();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => AlterarPedidoDelivery(
                            servico: s,
                            pedido: pedidoTeste(),
                            alteracao: AlteracaoDelivery.cancelar)),
                    child: const Text('Cancelar venda'))))));
    await tester.tap(find.text('Cancelar venda'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<EditableText>(find.byType(EditableText).first)
            .focusNode
            .hasFocus,
        isTrue);
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        isTrue);
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).first).obscureText,
        isFalse);
    await tester.enterText(find.byType(TextField).first, 'errada');
    await tester.enterText(find.byType(TextField).last, 'Cliente desistiu');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(find.text('Senha Admin de cancelamento incorreta.'), findsOneWidget);
    expect(s.gravacoes, isEmpty);
    await tester.enterText(find.byType(TextField).first, 'senha-teste');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$2['acao'], 'cancelar');
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelamento permite motivo vazio quando configuracao nao exige',
      (tester) async {
    final s = ServicoCancelamentoTeste();
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => AlterarPedidoDelivery(
                            servico: s,
                            pedido: pedidoTeste(),
                            alteracao: AlteracaoDelivery.cancelar)),
                    child: const Text('Cancelar venda'))))));

    await tester.tap(find.text('Cancelar venda'));
    await tester.pumpAndSettle();
    expect(find.text('Motivo do cancelamento (opcional)'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'senha-teste');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$2['motivo'], isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelamento exige motivo quando permissao esta ativa',
      (tester) async {
    final s = ServicoCancelamentoTeste()
      ..config = const ConfigDelivery(motivoCancelamentoObrigatorio: true);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => showDialog<bool>(
                        context: context,
                        builder: (_) => AlterarPedidoDelivery(
                            servico: s,
                            pedido: pedidoTeste(),
                            alteracao: AlteracaoDelivery.cancelar)),
                    child: const Text('Cancelar venda'))))));

    await tester.tap(find.text('Cancelar venda'));
    await tester.pumpAndSettle();
    expect(find.text('Motivo do cancelamento *'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'senha-teste');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(find.text('Informe o motivo do cancelamento.'), findsOneWidget);
    expect(s.gravacoes, isEmpty);

    await tester.enterText(find.byType(TextField).last, 'Cliente desistiu');
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();

    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$2['motivo'], 'Cliente desistiu');
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo endereco carrega cidade e cep padrao', (tester) async {
    final s = ServicoEnderecoPadraoTeste([]);
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    expect(find.text('86.770-000'), findsOneWidget);
    expect(find.text('Santa Fe'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo endereco nao marca padrao se cliente ja tem um',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([
      {'id': '10', 'padrao': 'Sim'}
    ]);
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo endereco exige campos quando configuracao obriga endereco',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([]);
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsWidgets);
    expect(s.gravacoes, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'novo endereco permite salvar campos vazios quando endereco nao e obrigatorio',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([], requeridoEndereco: 'Não');
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();
    expect(find.text('Campo obrigatório'), findsNothing);
    expect(s.gravacoes, hasLength(1));
    expect(s.gravacoes.single.$1, 'clientes/inserir_endereco.php');
    expect(tester.takeException(), isNull);
  });

  testWidgets('editar endereco preenche dados e salva com id existente',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([], requeridoEndereco: 'Não');
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
      endereco: const {
        'id': '10',
        'cep': '86.790-000',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'estado': 'PR',
        'complemento': 'Casa',
        'padrao': 'Sim',
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Editar endereço'), findsOneWidget);
    expect(find.text('Rua Luiz Roncalha'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).at(1), 'Rua Atualizada');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(s.gravacoes.single.$1, 'clientes/inserir_endereco.php');
    expect(s.gravacoes.single.$2['id'], '10');
    expect(s.gravacoes.single.$2['endereco'], 'Rua Atualizada');
    expect(s.gravacoes.single.$2['padrao'], 'Sim');
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo delivery abre edicao do endereco selecionado',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([
      {
        'id': '10',
        'cep': '86.790-000',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'estado': 'PR',
        'padrao': 'Sim',
      }
    ]);
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(
      servico: s,
      editarPedido: pedidoTeste(campos: {'idendereco': '10'}),
      aoSalvarEdicao: (_) async {},
    )));
    await tester.pumpAndSettle();

    final editarEndereco = find.byTooltip('Editar endereço');
    final novoEndereco = find.byKey(const ValueKey('novo-endereco'));
    await tester.scrollUntilVisible(
      editarEndereco,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(editarEndereco, findsOneWidget);
    expect(novoEndereco, findsOneWidget);
    expect(
      tester.getBottomLeft(editarEndereco).dy,
      lessThan(tester.getTopLeft(novoEndereco).dy),
    );
    await tester.ensureVisible(editarEndereco);
    await tester.pumpAndSettle();
    await tester.tap(editarEndereco);
    await tester.pumpAndSettle();

    expect(find.text('Editar endereço'), findsOneWidget);
    expect(find.text('Rua Luiz Roncalha'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'novo delivery seleciona endereco recem-criado sem alterar o padrao',
      (tester) async {
    final s = ServicoNovoEnderecoTeste([
      {
        'id': '10',
        'cep': '86.790-000',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'estado': 'PR',
        'padrao': 'Sim',
      }
    ]);
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(
      servico: s,
      editarPedido: pedidoTeste(campos: {'idendereco': '10'}),
      aoSalvarEdicao: (_) async {},
    )));
    await tester.pumpAndSettle();

    final novoEndereco = find.byKey(const ValueKey('novo-endereco'));
    await tester.scrollUntilVisible(
      novoEndereco,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(novoEndereco);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(1), 'Rua Teste');
    await tester.enterText(find.byType(TextFormField).at(2), '555');
    await tester.enterText(find.byType(TextFormField).at(4), 'Lobato');
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();

    final enderecoCriado = find.widgetWithText(ListTile, 'Rua Teste, 555');
    await tester.scrollUntilVisible(
      enderecoCriado,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<ListTile>(enderecoCriado).selected, isTrue);
    expect(s.enderecos.first['padrao'], 'Sim');
    expect(s.enderecos.last['padrao'], 'Não');
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo delivery mostra quatro mensagens em duas colunas e envia',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([
      {
        'id': '10',
        'cep': '86.790-000',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'estado': 'PR',
        'padrao': 'Sim',
      }
    ]);
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(
      servico: s,
      editarPedido: pedidoTeste(campos: {'idendereco': '10'}),
      aoSalvarEdicao: (_) async {},
    )));
    await tester.pumpAndSettle();

    final endereco = find.byKey(const ValueKey('mensagem-delivery-endereco'));
    final forma = find.byKey(const ValueKey('mensagem-delivery-forma'));
    final bebida = find.byKey(const ValueKey('mensagem-delivery-bebida'));
    final mais = find.byKey(const ValueKey('mensagem-delivery-mais'));
    await tester.scrollUntilVisible(
      mais,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Mensagens no WhatsApp'), findsOneWidget);
    expect(endereco, findsOneWidget);
    expect(forma, findsOneWidget);
    expect(bebida, findsOneWidget);
    expect(mais, findsOneWidget);
    final larguraTela = tester.getSize(find.byType(Scaffold)).width;
    expect(tester.getRect(endereco).left, lessThanOrEqualTo(17));
    expect(tester.getRect(forma).right, greaterThanOrEqualTo(larguraTela - 17));
    expect(tester.getSize(endereco).width, tester.getSize(forma).width);
    expect(tester.getTopLeft(endereco).dy, tester.getTopLeft(forma).dy);
    expect(tester.getTopLeft(bebida).dy, tester.getTopLeft(mais).dy);
    expect(tester.getTopLeft(bebida).dy,
        greaterThan(tester.getTopLeft(endereco).dy));

    await tester.tap(forma);
    await tester.pumpAndSettle();

    expect(s.notificacoes, hasLength(1));
    expect(
        s.notificacoes.single.mensagem, MensagemClienteDelivery.formaPagamento);
    expect(s.notificacoes.single.cliente, '4');
    expect(s.notificacoes.single.endereco, '10');
    expect(find.text('Enviado com sucesso!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca de cliente mostra celular na lista', (tester) async {
    String? termoBuscado;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => buscarDelivery(
                          context,
                          titulo: 'Selecionar cliente',
                          buscar: (termo) async {
                            termoBuscado = termo;
                            return [
                              {
                                'id': '4',
                                'nome_puro': 'Bruno Masson',
                                'celular': '44999213336',
                              }
                            ];
                          },
                          nome: (e) => e['nome_puro'].toString(),
                          detalhe: (e) => 'Celular: ${e['celular']}',
                          novo: (_) async => {
                            'id': '9',
                            'nome': 'Cliente Novo',
                          },
                          buscarCelular: true,
                        ),
                    child: const Text('Buscar cliente'))))));

    await tester.tap(find.text('Buscar cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Razão social, nome ou celular'), findsOneWidget);
    expect(find.text('Últimos 4 dígitos do celular'), findsOneWidget);
    expect(find.text('Novo Cliente'), findsOneWidget);
    final camposBusca = find.byType(TextField);
    expect(tester.getTopLeft(find.byType(FilledButton)).dy,
        lessThan(tester.getTopLeft(camposBusca.first).dy));
    expect(tester.getTopLeft(camposBusca.first).dy,
        lessThan(tester.getTopLeft(camposBusca.last).dy));
    await tester.enterText(find.byType(TextField).last, '3336');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(termoBuscado, '3336');
    expect(find.text('Bruno Masson'), findsOneWidget);
    expect(find.text('Celular: 44999213336'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
