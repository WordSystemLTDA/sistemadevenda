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
}

class _ModuloFinalizacao extends Module {
  @override
  void binds(Injector i) {
    i.addInstance<ServicoCardapio>(_CardapioFinalizacaoFake());
    i.addInstance<ServicoFinalizarPagamento>(_PagamentoFinalizacaoFake());
  }
}

void main() {
  setUp(() => Modular.init(_ModuloFinalizacao()));
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

    await tester.tap(find.text('Por pessoa'));
    await tester.pumpAndSettle();
    expect(find.text('Quantidade de pessoas'), findsOneWidget);
    expect(find.textContaining('Cota atual:'), findsOneWidget);
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
    await tester.scrollUntilVisible(find.text('Movimentos realizados'), 180,
        scrollable: lista.first);
    expect(find.text('Movimentos realizados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mantem a tela utilizavel em aparelho estreito e fonte grande',
      (tester) async {
    await abrir(tester, tamanho: const Size(320, 568), escala: 2);
    expect(find.text('Finalizar Conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
