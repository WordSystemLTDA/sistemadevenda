import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/fluxo_finalizacao_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_metodo_pagamento_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

class _PagamentoFake extends Fake implements ServicoFinalizarPagamento {
  final chamadas = <Map<String, Object?>>[];

  @override
  Future<
      ({
        bool sucesso,
        String mensagem,
        bool finalizou,
        String idVenda,
        double totalPago,
      })> pagarContaAtendimento({
    required String id,
    required String idComanda,
    required String idMesa,
    required String cliente,
    required TipoCardapio tipo,
    required double valorLancamento,
    required double valorOriginal,
    required double valorAPagar,
    required double troco,
    required int pagamentoSelecionado,
    required int quantidadePessoas,
    required DateTime vencimento,
    required List<Modelowordprodutos> produtosParaFinalizar,
    required bool modoProdutoParcial,
    String valorTaxaServico = '0',
    String valorDesconto = '0',
    String valorAcrescimo = '0',
  }) async {
    chamadas.add({
      'valorLancamento': valorLancamento,
      'valorAPagar': valorAPagar,
      'troco': troco,
      'modoProdutoParcial': modoProdutoParcial,
      'produtos': produtosParaFinalizar,
    });
    return (
      sucesso: true,
      mensagem: 'Pagamento registrado.',
      finalizou: false,
      idVenda: '138',
      totalPago: valorLancamento - troco,
    );
  }
}

class _ModuloTeste extends Module {
  final _PagamentoFake pagamento;

  _ModuloTeste(this.pagamento);

  @override
  void binds(Injector i) {
    i.addInstance<ServicoFinalizarPagamento>(pagamento);
  }
}

Modelowordprodutos _produto() => Modelowordprodutos(
      id: '100',
      iditensvenda: '77',
      nome: 'Produtos selecionados',
      codigo: '100',
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: '45.00',
      valorTotalVendas: '45.00',
      valorPago: '0',
      categoria: '1',
      nomeCategoria: 'Teste',
      habilTipo: '',
      ingredientes: const [],
      quantidade: 1,
    );

FluxoFinalizacaoAtendimento _fluxo(ModoRecebimentoAtendimento modo) =>
    FluxoFinalizacaoAtendimento(
      idAtendimento: '138',
      idComanda: '3',
      idMesa: '0',
      idCliente: '8',
      titulo: 'Comanda: 3',
      tipo: TipoCardapio.comanda,
      modo: modo,
      quantidadePessoas: 1,
      produtosSelecionados: modo == ModoRecebimentoAtendimento.porProduto
          ? [_produto()]
          : const [],
      valorBaseCentavos: 4500,
      valorPagoCentavos: 0,
      valorDescontoCentavos: 0,
      valorAcrescimoCentavos: 0,
      valorTaxaServico: '0',
    );

void main() {
  late _PagamentoFake pagamento;

  setUp(() {
    pagamento = _PagamentoFake();
    Modular.init(_ModuloTeste(pagamento));
  });
  tearDown(Modular.destroy);

  Future<void> abrir(
    WidgetTester tester,
    ModoRecebimentoAtendimento modo,
  ) async {
    tester.view.physicalSize = const Size(430, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: PaginaMetodoPagamentoAtendimento(
        fluxo: _fluxo(modo),
        forma: BancoPixModelo(id: '1', nome: 'Dinheiro'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> informarValor(WidgetTester tester, String valor) async {
    await tester.enterText(
      find.byKey(const ValueKey('valor_recebido_atendimento')),
      valor,
    );
    await tester.pumpAndSettle();
  }

  Future<void> finalizar(WidgetTester tester) async {
    final botao = find.byKey(const ValueKey('finalizar_pagamento_atendimento'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();
  }

  testWidgets('produto recebe parte em dinheiro e preserva o restante',
      (tester) async {
    await abrir(tester, ModoRecebimentoAtendimento.porProduto);
    await informarValor(tester, '30');

    expect(
        find.byKey(const ValueKey('falta_pagamento_produtos')), findsOneWidget);
    expect(find.text('Falta para os produtos selecionados'), findsOneWidget);
    expect(find.textContaining('15,00'), findsOneWidget);

    await finalizar(tester);
    expect(find.textContaining('Restará'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    expect(pagamento.chamadas, hasLength(1));
    final chamada = pagamento.chamadas.single;
    expect(chamada['valorLancamento'], 30);
    expect(chamada['valorAPagar'], 45);
    expect(chamada['troco'], 0);
    expect(chamada['modoProdutoParcial'], isTrue);
    expect(chamada['produtos'], hasLength(1));
  });

  testWidgets('produto calcula troco sem registrar valor acima do devido',
      (tester) async {
    await abrir(tester, ModoRecebimentoAtendimento.porProduto);
    await informarValor(tester, '50');

    expect(find.text('Troco'), findsOneWidget);
    expect(
      find.byWidgetPredicate((widget) =>
          widget is Text &&
          widget.data?.contains('5,00') == true &&
          widget.data?.contains('45,00') == false),
      findsOneWidget,
    );
    expect(
        find.byKey(const ValueKey('falta_pagamento_produtos')), findsNothing);

    await finalizar(tester);
    expect(find.textContaining('Troco:'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();

    final chamada = pagamento.chamadas.single;
    expect(chamada['valorLancamento'], 50);
    expect(chamada['valorAPagar'], 45);
    expect(chamada['troco'], 5);
  });

  testWidgets('conta inteira continua bloqueando dinheiro insuficiente',
      (tester) async {
    await abrir(tester, ModoRecebimentoAtendimento.contaInteira);
    await informarValor(tester, '30');
    await finalizar(tester);

    expect(find.text('O valor recebido em dinheiro é insuficiente.'),
        findsOneWidget);
    expect(pagamento.chamadas, isEmpty);
  });
}
