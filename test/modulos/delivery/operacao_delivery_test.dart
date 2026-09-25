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
import 'package:app/src/modulos/delivery/servicos/preferencia_mensagens_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
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
  final String ativarCardapioDigital;
  ServicoEnderecoPadraoTeste(
    this.enderecos, {
    this.requeridoEndereco = 'Sim',
    this.ativarCardapioDigital = 'Almoço',
  });

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
    if (rota == 'config_bigchef/listar.php') {
      final resposta = await super.consultar(rota, campos);
      return {
        if (resposta is Map) ...Map<String, dynamic>.from(resposta),
        'ativarcardapiodigital': ativarCardapioDigital,
      };
    }
    return super.consultar(rota, campos);
  }
}

class ServicoNovoEnderecoTeste extends ServicoEnderecoPadraoTeste {
  ServicoNovoEnderecoTeste(super.enderecos, {super.requeridoEndereco});

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final resposta = await super.salvar(rota, campos);
    if (rota == 'clientes/inserir_endereco.php' && campos['id'] != '') {
      final endereco =
          enderecos.where((e) => '${e['id']}' == '${campos['id']}').firstOrNull;
      if (endereco != null) endereco['padrao'] = campos['padrao'];
    } else if (rota == 'clientes/inserir_endereco.php' && campos['id'] == '') {
      if (campos['padrao'] == 'Sim' && campos['substituirPadrao'] == true) {
        for (final endereco in enderecos) {
          endereco['padrao'] = 'Não';
        }
      }
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

class ServicoEdicaoClienteTeste extends ServicoEnderecoPadraoTeste {
  ServicoEdicaoClienteTeste(super.enderecos);

  final dadosCliente = <String, dynamic>{
    'id': '4',
    'nome': 'Bruno Masson',
    'nome_puro': 'Bruno Masson',
    'celular': '(44) 99921-3336',
    'email': 'bruno@teste.com',
    'obs': 'Cliente antigo',
  };

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'comandas/listar_clientes.php') {
      return campos['pesquisa'] == '4' ? [dadosCliente] : const [];
    }
    return super.consultar(rota, campos);
  }

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final resposta = await super.salvar(rota, campos);
    if (rota == 'comandas/inserir_cliente.php') {
      dadosCliente.addAll({
        'nome': campos['nome'],
        'nome_puro': campos['nome'],
        'celular': campos['celular'],
        'email': campos['email'],
        'obs': campos['obs'],
      });
    }
    return resposta;
  }
}

class ServicoMensagensAutomaticasTeste extends ServicoDeliveryTeste {
  MensagemClienteDelivery? falharEm;

  @override
  Future<String> notificarCliente(
    MensagemClienteDelivery mensagem, {
    String cliente = '0',
    String endereco = '0',
    String idDelivery = '0',
    String valorPedido = '',
  }) async {
    final resultado = await super.notificarCliente(
      mensagem,
      cliente: cliente,
      endereco: endereco,
      idDelivery: idDelivery,
      valorPedido: valorPedido,
    );
    if (mensagem == falharEm) throw StateError('Falha simulada');
    return resultado;
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('preferencia de mensagens automaticas fica salva no aparelho', () async {
    final preferencia = PreferenciaMensagensDelivery();
    expect(await preferencia.carregar(), isEmpty);

    await preferencia.salvar({
      MensagemClienteDelivery.confirmarEndereco,
      MensagemClienteDelivery.oferecerBebida,
    });

    expect(await preferencia.carregar(), {
      MensagemClienteDelivery.confirmarEndereco,
      MensagemClienteDelivery.oferecerBebida,
    });
    expect(
      (await SharedPreferences.getInstance())
          .getStringList(PreferenciaMensagensDelivery.chave),
      ['bebida', 'endereco'],
    );
  });

  test('fila automatica ignora cliente sem celular', () async {
    final servico = ServicoMensagensAutomaticasTeste();

    await enviarMensagensAutomaticasDelivery(
      servico: servico,
      idDelivery: '25',
      celularCliente: '',
      tipoEntrega: '1',
      possuiEndereco: true,
      mensagensHabilitadas: {MensagemClienteDelivery.confirmarEndereco},
    );

    expect(servico.notificacoes, isEmpty);
  });

  test(
      'fila automatica envia somente mensagens escolhidas e continua apos falha',
      () async {
    final servico = ServicoMensagensAutomaticasTeste()
      ..falharEm = MensagemClienteDelivery.formaPagamento;
    final falhas = <MensagemClienteDelivery>[];

    await enviarMensagensAutomaticasDelivery(
      servico: servico,
      idDelivery: '25',
      celularCliente: '(44) 99921-3336',
      tipoEntrega: '1',
      possuiEndereco: true,
      mensagensHabilitadas: {
        MensagemClienteDelivery.formaPagamento,
        MensagemClienteDelivery.algoMais,
      },
      aoFalhar: (mensagem, _, __) => falhas.add(mensagem),
    );

    expect(
      servico.notificacoes.map((item) => item.mensagem),
      [
        MensagemClienteDelivery.formaPagamento,
        MensagemClienteDelivery.algoMais,
      ],
    );
    expect(
      servico.notificacoes.map((item) => item.idDelivery).toSet(),
      {'25'},
    );
    expect(falhas, [MensagemClienteDelivery.formaPagamento]);
  });

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

  for (final caso in [
    (tipoEntrega: '1', tipoImpressao: '3', comprovante: 'entregador'),
    (tipoEntrega: '2', tipoImpressao: '2', comprovante: 'consumo'),
  ]) {
    testWidgets(
        'PREPARAR imprime comprovante de ${caso.comprovante} com preparo quando configurado',
        (tester) async {
      final servidor = impressao.ServidorTeste();
      Modular.init(impressao.ModuloImpressaoTeste(servidor));
      addTearDown(Modular.destroy);
      final s = ServicoDeliveryTeste()
        ..config = const ConfigDelivery(
          receberNoFinal: true,
          imprimirPreparo: true,
          imprimirPreparoNoComprovanteConsumacao: true,
        )
        ..produtosCardapio = [
          impressao.produto(computador: 'COZINHA')..observacao = 'Sem cebola'
        ];
      s.atual = pedidoTeste(campos: {
        'id': '1',
        'idopcoescarrossel': '1',
        'tipodeentrega': caso.tipoEntrega,
        'quantidadeprodutos': '1',
      });
      s.respostaLista = () async => [
            EtapaDelivery.fromMap({
              'id': '1',
              'nomeOpcao': 'AGUARDANDO',
              'nomeBotao': 'PREPARAR',
              'tipodeimpressao': '0',
              'vendas': [s.atual.dados],
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
      await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('PREPARAR'));
      await tester.pumpAndSettle();

      expect(servidor.mensagens, hasLength(1));
      expect(servidor.mensagens.single['tipoImpressao'], caso.tipoImpressao);
      final produto =
          (servidor.mensagens.single['produtos'] as List).single as Map;
      expect(produto['observacao'], 'Sem cebola');
      expect(s.gravacoes.single.$1, 'delivery/mudar_status_delivery.php');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'PREPARAR mantem comprovante de preparo separado quando opcao e Não',
      (tester) async {
    final servidor = impressao.ServidorTeste();
    Modular.init(impressao.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final s = ServicoDeliveryTeste()
      ..config = const ConfigDelivery(
        receberNoFinal: true,
        imprimirPreparo: true,
        imprimirPreparoNoComprovanteConsumacao: false,
      )
      ..produtosCardapio = [impressao.produto(computador: 'COZINHA')];
    s.atual = pedidoTeste(campos: {
      'id': '1',
      'idopcoescarrossel': '1',
      'quantidadeprodutos': '1',
    });
    s.respostaLista = () async => [
          EtapaDelivery.fromMap({
            'id': '1',
            'nomeOpcao': 'AGUARDANDO',
            'nomeBotao': 'PREPARAR',
            'tipodeimpressao': '0',
            'vendas': [s.atual.dados],
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
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: p)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('PREPARAR'));
    await tester.pumpAndSettle();

    expect(servidor.mensagens, hasLength(1));
    expect(servidor.mensagens.single['tipoImpressao'], '1');
    expect(tester.takeException(), isNull);
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
    expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Endereço padrão'))
            .value,
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
    expect(
        tester
            .widget<SwitchListTile>(
                find.widgetWithText(SwitchListTile, 'Endereço padrão'))
            .value,
        isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recusar troca salva novo endereco sem alterar o endereco padrao',
      (tester) async {
    final s = ServicoNovoEnderecoTeste([
      {'id': '10', 'padrao': 'Sim'}
    ], requeridoEndereco: 'Não');
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Endereço padrão'));
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();

    expect(find.text('Alterar endereço padrão?'), findsOneWidget);
    expect(
        find.text(
            'Este cliente já possui um endereço padrão. Deseja mudar o endereço padrão para este endereço atual?'),
        findsOneWidget);
    await tester.tap(find.text('Não'));
    await tester.pumpAndSettle();

    expect(s.gravacoes.single.$2['padrao'], 'Não');
    expect(s.gravacoes.single.$2['substituirPadrao'], isFalse);
    expect(s.enderecos.first['padrao'], 'Sim');
    expect(s.enderecos.last['padrao'], 'Não');
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirmar troca transfere o endereco padrao para o novo',
      (tester) async {
    final s = ServicoNovoEnderecoTeste([
      {'id': '10', 'padrao': 'Sim'}
    ], requeridoEndereco: 'Não');
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'Endereço padrão'));
    await tester.tap(find.text('Salvar endereço'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sim, alterar'));
    await tester.pumpAndSettle();

    expect(s.gravacoes, hasLength(2));
    expect(s.gravacoes.first.$2['id'], '10');
    expect(s.gravacoes.first.$2['padrao'], 'Não');
    expect(s.gravacoes.last.$2['padrao'], 'Sim');
    expect(s.gravacoes.last.$2['substituirPadrao'], isTrue);
    expect(s.enderecos.first['padrao'], 'Não');
    expect(s.enderecos.last['padrao'], 'Sim');
    expect(s.enderecos.where((endereco) => endereco['padrao'] == 'Sim'),
        hasLength(1));
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

  testWidgets('novo delivery mostra novo cliente enquanto nao ha selecao',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste(const []);
    await tester.pumpWidget(MaterialApp(home: PaginaNovoDelivery(servico: s)));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('novo-cliente')), findsOneWidget);
    expect(find.text('Novo Cliente'), findsOneWidget);
    expect(find.byKey(const ValueKey('editar-cliente')), findsNothing);
    expect(find.text('Editar Cliente'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cliente selecionado pode ser editado sem perder o endereco',
      (tester) async {
    tester.view.physicalSize = const Size(600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = ServicoEdicaoClienteTeste([
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
    ])
      ..dadosCliente['celular'] = '';
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(
      servico: s,
      clonar: pedidoTeste(campos: {
        'idendereco': '10',
        'celularCliente': '',
      }),
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('editar-cliente')), findsOneWidget);
    expect(find.text('Editar Cliente'), findsOneWidget);
    expect(find.byKey(const ValueKey('novo-cliente')), findsNothing);
    expect(find.text('Mensagens no WhatsApp'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('editar-cliente')));
    await tester.pumpAndSettle();

    expect(find.text('Editar cliente'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('cliente-email')))
            .controller!
            .text,
        'bruno@teste.com');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-nome')), 'Bruno Atualizado');
    await tester.enterText(
        find.byKey(const ValueKey('cliente-celular')), '44999887766');
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();

    expect(find.text('Bruno Atualizado'), findsOneWidget);
    expect(find.text('(44) 99988-7766'), findsOneWidget);
    expect(find.byKey(const ValueKey('editar-cliente')), findsOneWidget);
    expect(find.text('Mensagens no WhatsApp'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('mensagem-automatica-endereco')),
      findsOneWidget,
    );
    final gravacaoCliente = s.gravacoes
        .where((registro) => registro.$1 == 'comandas/inserir_cliente.php')
        .single;
    expect(gravacaoCliente.$2['id'], '4');
    expect(gravacaoCliente.$2['nome'], 'Bruno Atualizado');
    expect(find.widgetWithText(ListTile, 'Rua Luiz Roncalha, 169'),
        findsOneWidget);
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

  testWidgets('novo delivery mostra local taxa e padrao em cada endereco',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([
      {
        'id': '10',
        'cep': '86.790-000',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'padrao': 'Sim',
        'tipolocalentrega': 'Normal',
        'origemtaxaentrega': 'Fixo',
        'periodotaxaentrega': 'Diurno',
        'taxaentregacalculada': '4.00',
      },
      {
        'id': '11',
        'cep': '86.790-000',
        'endereco': 'Endereço de Sítio',
        'numero': '1',
        'cidade': 'Lobato',
        'padrao': 'Não',
        'tipolocalentrega': 'Sitio',
        'origemtaxaentrega': 'Sitio',
        'periodotaxaentrega': 'Diurno',
        'taxaentregacalculada': '5.00',
      },
    ]);
    await tester.pumpWidget(MaterialApp(
      home: PaginaNovoDelivery(
        servico: s,
        editarPedido: pedidoTeste(campos: {'idendereco': '10'}),
        aoSalvarEdicao: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(
        find.text('Jardim Italia • Santa Fé • CEP 86.790-000'), findsOneWidget);
    expect(find.text('Fixo • Diurno • R\$ 4,00'), findsOneWidget);
    expect(find.text('Padrão do cliente'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Endereço de Sítio, 1'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Lobato • CEP 86.790-000'), findsOneWidget);
    expect(find.text('Sítio • Sítio • Diurno • R\$ 5,00'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo delivery oculta mensagens quando cliente nao tem celular',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste([
      {
        'id': '10',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'padrao': 'Sim',
      }
    ]);
    await tester.pumpWidget(MaterialApp(
      home: PaginaNovoDelivery(
        servico: s,
        editarPedido: pedidoTeste(campos: {
          'idendereco': '10',
          'celularCliente': '',
        }),
        aoSalvarEdicao: (_) async {},
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Mensagens no WhatsApp'), findsNothing);
    expect(
      find.byKey(const ValueKey('mensagem-automatica-endereco')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('mensagem-delivery-cardapio')),
      findsNothing,
    );
  });

  testWidgets('novo delivery salva cada envio automatico separadamente',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final s = ServicoEnderecoPadraoTeste([
      {
        'id': '10',
        'endereco': 'Rua Luiz Roncalha',
        'numero': '169',
        'bairro': 'Jardim Italia',
        'cidade': 'Santa Fé',
        'padrao': 'Sim',
      }
    ]);
    await tester.pumpWidget(MaterialApp(
      home: PaginaNovoDelivery(
        servico: s,
        clonar: pedidoTeste(campos: {
          'idendereco': '10',
          'celularCliente': '(44) 99921-3336',
        }),
      ),
    ));
    await tester.pumpAndSettle();
    final enderecoAutomatico = find.byKey(
      const ValueKey('mensagem-automatica-endereco'),
    );
    final bebidaAutomatica = find.byKey(
      const ValueKey('mensagem-automatica-bebida'),
    );
    final formaAutomatica = find.byKey(
      const ValueKey('mensagem-automatica-forma'),
    );
    await tester.scrollUntilVisible(
      bebidaAutomatica,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(enderecoAutomatico, findsOneWidget);
    expect(bebidaAutomatica, findsOneWidget);
    expect(formaAutomatica, findsOneWidget);
    await tester.ensureVisible(enderecoAutomatico);
    await tester.tap(enderecoAutomatico);
    await tester.pumpAndSettle();
    await tester.ensureVisible(bebidaAutomatica);
    await tester.tap(bebidaAutomatica);
    await tester.pumpAndSettle();

    bool marcado(Finder opcao) => tester
        .widget<Checkbox>(
          find.descendant(of: opcao, matching: find.byType(Checkbox)),
        )
        .value!;

    expect(marcado(enderecoAutomatico), isTrue);
    expect(marcado(bebidaAutomatica), isTrue);
    expect(marcado(formaAutomatica), isFalse);
    expect(
      (await SharedPreferences.getInstance())
          .getStringList(PreferenciaMensagensDelivery.chave),
      ['bebida', 'endereco'],
    );
  });

  testWidgets(
      'novo delivery seleciona endereco recem-criado sem alterar o padrao',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    expect(find.byKey(const ValueKey('endereco-padrao-10')), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -120));
    await tester.pumpAndSettle();
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
    expect(find.byKey(const ValueKey('endereco-padrao-11')), findsNothing);
    expect(s.enderecos.first['padrao'], 'Sim');
    expect(s.enderecos.last['padrao'], 'Não');
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo delivery oculta cardapio quando configuracao nao e Almoco',
      (tester) async {
    final s = ServicoEnderecoPadraoTeste(
      [
        {
          'id': '10',
          'endereco': 'Rua Luiz Roncalha',
          'numero': '169',
          'bairro': 'Jardim Italia',
          'padrao': 'Sim',
        }
      ],
      ativarCardapioDigital: 'Jantar',
    );
    await tester.pumpWidget(MaterialApp(
        home: PaginaNovoDelivery(
      servico: s,
      editarPedido: pedidoTeste(campos: {
        'idendereco': '10',
        'celularCliente': '(44) 99921-3336',
      }),
      aoSalvarEdicao: (_) async {},
    )));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('mensagem-delivery-cardapio')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('novo delivery mostra mensagens e envia o cardapio no Almoco',
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
      editarPedido: pedidoTeste(campos: {
        'idendereco': '10',
        'celularCliente': '(44) 99921-3336',
      }),
      aoSalvarEdicao: (_) async {},
    )));
    await tester.pumpAndSettle();

    final endereco = find.byKey(const ValueKey('mensagem-delivery-endereco'));
    final forma = find.byKey(const ValueKey('mensagem-delivery-forma'));
    final bebida = find.byKey(const ValueKey('mensagem-delivery-bebida'));
    final mais = find.byKey(const ValueKey('mensagem-delivery-mais'));
    final cardapio = find.byKey(const ValueKey('mensagem-delivery-cardapio'));
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
    expect(cardapio, findsOneWidget);
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

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.ensureVisible(cardapio);
    await tester.pumpAndSettle();
    await tester.tap(cardapio);
    await tester.pumpAndSettle();

    expect(s.cardapiosEnviados, 1);
    expect(find.text('Cardápio enviado com sucesso!'), findsOneWidget);
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
