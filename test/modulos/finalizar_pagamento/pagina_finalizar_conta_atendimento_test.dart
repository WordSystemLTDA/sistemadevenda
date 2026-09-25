import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_destino_impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/bancos_ativos_pdv_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_conta_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

class _CardapioFinalizacaoFake extends Fake implements ServicoCardapio {
  String? senhaCancelamento;
  int leiturasFinalizadas = 0;

  Modeloworddadoscardapio _atendimento({
    required String id,
    required TipoCardapio tipo,
    String status = 'Andamento',
    bool pagamentoCompleto = false,
  }) {
    return Modeloworddadoscardapio(
      id: id,
      idComanda: tipo == TipoCardapio.comanda ? '3' : '0',
      idMesa: tipo == TipoCardapio.mesa ? '3' : '0',
      idCliente: '8',
      nome: '${tipo.nome}: 3',
      nomeMesa: tipo == TipoCardapio.mesa ? 'Mesa: 3' : '',
      nomeCliente: 'Cliente teste',
      nomeEmpresa: 'Restaurante teste',
      celularEmpresa: '(44) 99999-0000',
      cnpjEmpresa: '00.000.000/0001-00',
      enderecoEmpresa: 'Rua do Restaurante, 10',
      dataAbertura: '2026-09-24T18:00:00',
      numeroPedido: '44',
      status: status,
      valorTotal: '85.00',
      somaValorHistorico: pagamentoCompleto ? '85.00' : '20.00',
      quantidadePessoas: 2,
      nomelancamento: [
        ModeloNomeLancamento(nome: 'Dinheiro', valor: '20.00'),
        if (pagamentoCompleto)
          ModeloNomeLancamento(nome: 'Dinheiro', valor: '65.00'),
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
        Modelowordprodutos(
          id: '1',
          iditensvenda: '78',
          nome: 'Pizza de Queijos',
          codigo: '1',
          estoque: '0',
          tamanho: 'Grande',
          foto: '',
          ativo: 'Sim',
          descricao: '',
          valorVenda: '47.00',
          valorTotalVendas: '47.00',
          categoria: '2',
          nomeCategoria: 'Pizzas',
          habilTipo: '',
          ingredientes: const [],
          quantidade: 1,
          opcoesPacotesListaFinal: [
            ModeloOpcoesPacotes(
              id: 10,
              titulo: 'Sabores',
              obrigatorio: true,
              dados: [
                ModeloDadosOpcoesPacotes(
                  id: '1',
                  nome: 'Mussarela',
                  quantimaximaselecao: '1/2',
                  valor: '0',
                ),
                ModeloDadosOpcoesPacotes(
                  id: '2',
                  nome: 'Catupiry Especial',
                  quantimaximaselecao: '1/2',
                  valor: '0',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<Modeloworddadoscardapio> listarPorId(
      String id, TipoCardapio tipo, String mostraritens,
      {String? codigoQrcode}) async {
    return _atendimento(id: id, tipo: tipo);
  }

  @override
  Future<Modeloworddadoscardapio> listarFinalizadoParaImpressao(
      String id, TipoCardapio tipo) async {
    leiturasFinalizadas++;
    return _atendimento(
      id: id,
      tipo: tipo,
      status: 'Finalizada',
      pagamentoCompleto: true,
    );
  }

  @override
  Future<
      ({
        bool sucesso,
        String mensagem,
        ModeloDestinoImpressao? destinoCaixa,
      })> cancelarItemFinalizado({
    required TipoCardapio tipo,
    required Modeloworddadoscardapio atendimento,
    required Modelowordprodutos produto,
    required String idMesa,
    required String idComanda,
    required String senhaAdmin,
  }) async {
    senhaCancelamento = senhaAdmin;
    return (
      sucesso: false,
      mensagem: 'Cancelamento simulado.',
      destinoCaixa: null,
    );
  }
}

class _ServidorFinalizacaoFake extends Fake implements Server {
  final mensagens = <Map<String, dynamic>>[];

  @override
  Future<void> enviarImpressoes(List<String> novasMensagens) async {
    mensagens.addAll(novasMensagens.map(
        (mensagem) => Map<String, dynamic>.from(jsonDecode(mensagem) as Map)));
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
  final _CardapioFinalizacaoFake cardapio;
  final _ServidorFinalizacaoFake servidor;
  _ModuloFinalizacao(this.pagamento, this.cardapio, this.servidor);

  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(cardapio);
    i.addInstance<ServicoFinalizarPagamento>(pagamento);
    i.addInstance<Server>(servidor);
    i.addInstance<UsuarioProvedor>(UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '7', empresa: '9', nome: 'Operador')));
  }
}

void main() {
  late _PagamentoFinalizacaoFake pagamento;
  late _CardapioFinalizacaoFake cardapio;
  late _ServidorFinalizacaoFake servidor;
  setUp(() {
    pagamento = _PagamentoFinalizacaoFake();
    cardapio = _CardapioFinalizacaoFake();
    servidor = _ServidorFinalizacaoFake();
    Modular.init(_ModuloFinalizacao(pagamento, cardapio, servidor));
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
    await tester.drag(lista.first, const Offset(0, -120));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('selecionar_77')));
    await tester.pumpAndSettle();
    expect(find.textContaining('12,00'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('conferir_77')));
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

  testWidgets('abre detalhes de pizza e exige senha Admin para excluir',
      (tester) async {
    await abrir(tester);

    final lista = find.descendant(
        of: find.byType(ListView), matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.byTooltip('Ver detalhes'), 180,
        scrollable: lista.first);
    await tester.drag(lista.first, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(find.text('Sabores').hitTestable(), findsNothing);

    await tester.tap(find.byTooltip('Ver detalhes'));
    await tester.pumpAndSettle();
    expect(find.text('Sabores').hitTestable(), findsOneWidget);
    expect(find.text('(1/2) Mussarela').hitTestable(), findsOneWidget);
    expect(find.text('(1/2) Catupiry Especial').hitTestable(), findsOneWidget);

    final excluir = find.byKey(const ValueKey('excluir_78'));
    final conferir = find.byKey(const ValueKey('conferir_78'));
    expect((tester.getCenter(excluir).dy - tester.getCenter(conferir).dy).abs(),
        lessThan(1));

    final cardProduto = find.byKey(const ValueKey('produto_finalizacao_78'));
    final cardVisual =
        find.descendant(of: cardProduto, matching: find.byType(Card)).first;
    final corAntes = tester.widget<Card>(cardVisual).color;
    await tester.tap(conferir);
    await tester.pumpAndSettle();
    final contextoCard = tester.element(cardProduto);
    final corVerdeEsperada = Color.alphaBlend(
      VisualAtendimento.verde(contextoCard).withValues(alpha: 0.14),
      Theme.of(contextoCard).colorScheme.surface,
    );
    expect(tester.widget<Card>(cardVisual).color, corVerdeEsperada);
    expect(tester.widget<Card>(cardVisual).color, isNot(corAntes));
    expect(find.text('Conferido'), findsOneWidget);

    await tester.tap(excluir);
    await tester.pumpAndSettle();
    expect(find.text('Digite a senha Admin para confirmar o cancelamento.'),
        findsOneWidget);

    await tester.tap(find.text('Confirmar exclusão'));
    await tester.pump();
    expect(find.text('Informe a senha Admin.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'senha-admin');
    await tester.tap(find.text('Confirmar exclusão'));
    await tester.pumpAndSettle();
    expect(cardapio.senhaCancelamento, 'senha-admin');
    expect(find.text('Cancelamento simulado.'), findsOneWidget);
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

  for (final tipo in [TipoCardapio.comanda, TipoCardapio.mesa]) {
    testWidgets(
        'finalização de ${tipo.name} salva comprovante de consumo no caixa',
        (tester) async {
      tester.view.physicalSize = const Size(430, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        home: PaginaFinalizarContaAtendimento(
          idAtendimento: '138',
          idComanda: tipo == TipoCardapio.comanda ? '3' : '0',
          idMesa: tipo == TipoCardapio.mesa ? '3' : '0',
          tipo: tipo,
        ),
      ));
      await tester.pumpAndSettle();

      await tester
          .tap(find.byKey(const ValueKey('avancar_finalizacao_atendimento')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('avancar_acrescimos_atendimento')));
      await tester.pumpAndSettle();
      await tester.tap(
          find.byKey(const ValueKey('avancar_forma_pagamento_atendimento')));
      await tester.pumpAndSettle();
      await tester
          .tap(find.byKey(const ValueKey('finalizar_pagamento_atendimento')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Confirmar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Concluir'));
      await tester.pumpAndSettle();

      expect(cardapio.leiturasFinalizadas, 1);
      expect(servidor.mensagens, hasLength(1));
      final impressao = servidor.mensagens.single;
      expect(impressao['tipoImpressao'], '2');
      expect(impressao['protocoloImpressao'], 2);
      expect(impressao['tipo'], tipo.nome);
      expect(impressao.containsKey('nomedopc'), isFalse);
      expect(impressao['somaValorHistorico'], '85.00');
      expect(impressao['local'], '${tipo.nome}: 3');
      expect(impressao['idEmpresa'], '9');
      expect(tester.takeException(), isNull);
    });
  }
}
