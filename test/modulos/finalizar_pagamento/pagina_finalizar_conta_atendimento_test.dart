import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/bancos_ativos_pdv_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_conta_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

class _CardapioFinalizacaoFake extends Fake implements ServicoCardapio {
  @override
  Future<Modeloworddadoscardapio> listarPorId(
      String id, TipoCardapio tipo, String mostraritens,
      {String? codigoQrcode}) async {
    return Modeloworddadoscardapio(
      id: id,
      idComanda: '3',
      idMesa: '0',
      idCliente: '8',
      nome: 'Comanda: 3',
      nomeCliente: 'Cliente teste',
      status: 'Andamento',
      valorTotal: '85.00',
      somaValorHistorico: '20.00',
      quantidadePessoas: 2,
      nomelancamento: [
        ModeloNomeLancamento(nome: 'Dinheiro', valor: '20.00'),
      ],
      produtos: [
        Modelowordprodutos(
          id: '100',
          iditensvenda: '77',
          nome: 'Água Tônica',
          codigo: '100',
          estoque: '0',
          tamanho: '',
          foto: '',
          ativo: 'Sim',
          descricao: '',
          valorVenda: '6.00',
          valorTotalVendas: '18.00',
          valorPago: '6.00',
          categoria: '1',
          nomeCategoria: 'Bebidas',
          habilTipo: '',
          ingredientes: const [],
          quantidade: 3,
        ),
      ],
    );
  }
}

class _PagamentoFinalizacaoFake extends Fake
    implements ServicoFinalizarPagamento {
  int pagamentos = 0;

  @override
  Future<BancosAtivosPdvModelo> listarBancos() async => BancosAtivosPdvModelo(
        idBancoPix: '0',
        idBancoOpcao2: '0',
        idBancoOpcao3: '0',
        idBancoOpcao4: '0',
        idBancoOpcao5: '0',
        ativoBancoPix: 'Não',
        ativoBancoOpcao2: 'Não',
        ativoBancoOpcao3: 'Não',
        ativoBancoOpcao4: 'Não',
        ativoBancoOpcao5: 'Não',
        nomeBancoPix: '',
        nomeBancoOpcao2: '',
        nomeBancoOpcao3: '',
        nomeBancoOpcao4: '',
        nomeBancoOpcao5: '',
        pixdinamicopix: 'Não',
        pixdinamicoopcao2: 'Não',
        pixdinamicoopcao3: 'Não',
        pixdinamicoopcao4: 'Não',
        pixdinamicoopcao5: 'Não',
      );

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
    pagamentos++;
    return (
      sucesso: true,
      mensagem: 'Pagamento registrado.',
      finalizou: true,
      idVenda: '900',
      totalPago: valorAPagar,
    );
  }
}

class _ModuloFinalizacao extends Module {
  final _PagamentoFinalizacaoFake pagamento;
  _ModuloFinalizacao(this.pagamento);

  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(_CardapioFinalizacaoFake());
    i.addInstance<ServicoFinalizarPagamento>(pagamento);
  }
}

void main() {
  late _PagamentoFinalizacaoFake pagamento;
  setUp(() {
    pagamento = _PagamentoFinalizacaoFake();
    Modular.init(_ModuloFinalizacao(pagamento));
  });
  tearDown(Modular.destroy);

  Future<void> abrir(WidgetTester tester,
      {Size tamanho = const Size(430, 1000), double escala = 1}) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: const PaginaFinalizarContaAtendimento(
            idAtendimento: '138',
            idComanda: '3',
            idMesa: '0',
            tipo: TipoCardapio.comanda),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('exibe saldo, divisao por pessoa e selecao por produto',
      (tester) async {
    await abrir(tester);

    expect(find.text('Finalizar Conta'), findsOneWidget);
    expect(find.textContaining('65,00'), findsWidgets);
    expect(find.text('Forma de pagamento'), findsNothing);
    expect(find.text('Adicionar mais produtos'), findsOneWidget);

    await tester.tap(find.text('Por pessoa'));
    await tester.pumpAndSettle();
    expect(find.text('Quantidade de pessoas'), findsOneWidget);
    expect(find.textContaining('Valor por pessoa:'), findsOneWidget);
    expect(find.textContaining('22,50'), findsWidgets);

    await tester.tap(find.text('Por produtos'));
    await tester.pumpAndSettle();
    final lista = find.descendant(
        of: find.byType(ListView), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Água Tônica'), 160,
        scrollable: lista.first);
    await tester.tap(find.text('Água Tônica'));
    await tester.pumpAndSettle();
    expect(find.textContaining('12,00'), findsWidgets);
    await tester.tap(find.text('Conferir'));
    await tester.pumpAndSettle();
    expect(find.text('Conferido'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Movimentos realizados'), 180,
        scrollable: lista.first);
    expect(find.text('Movimentos realizados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('segue conferencia, ajustes, forma e metodo de pagamento',
      (tester) async {
    await abrir(tester, tamanho: const Size(320, 700), escala: 1.5);

    await tester
        .tap(find.byKey(const ValueKey('avancar_finalizacao_atendimento')));
    await tester.pumpAndSettle();
    expect(find.text('Acréscimo e Descontos'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'tela de ajustes');

    await tester
        .tap(find.byKey(const ValueKey('avancar_acrescimos_atendimento')));
    await tester.pumpAndSettle();
    expect(find.text('Forma de Pagamento'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'tela de formas');

    await tester
        .tap(find.byKey(const ValueKey('avancar_forma_pagamento_atendimento')));
    await tester.pumpAndSettle();
    expect(find.text('Método de Pagamento'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'tela do método');
    expect(find.text('Valor recebido'), findsOneWidget);
    expect(find.text('Finalizar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantem a tela utilizavel em aparelho estreito e fonte grande',
      (tester) async {
    await abrir(tester, tamanho: const Size(320, 568), escala: 2);
    expect(find.text('Finalizar Conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirma o movimento somente na ultima tela', (tester) async {
    await abrir(tester);

    await tester
        .tap(find.byKey(const ValueKey('avancar_finalizacao_atendimento')));
    await tester.pumpAndSettle();
    expect(pagamento.pagamentos, 0);

    await tester
        .tap(find.byKey(const ValueKey('avancar_acrescimos_atendimento')));
    await tester.pumpAndSettle();
    expect(pagamento.pagamentos, 0);

    await tester
        .tap(find.byKey(const ValueKey('avancar_forma_pagamento_atendimento')));
    await tester.pumpAndSettle();
    expect(pagamento.pagamentos, 0);

    await tester
        .tap(find.byKey(const ValueKey('finalizar_pagamento_atendimento')));
    await tester.pumpAndSettle();
    expect(find.text('Confirmar recebimento'), findsOneWidget);
    expect(pagamento.pagamentos, 0);

    await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
    await tester.pumpAndSettle();
    expect(pagamento.pagamentos, 1);
    expect(find.text('Conta finalizada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
