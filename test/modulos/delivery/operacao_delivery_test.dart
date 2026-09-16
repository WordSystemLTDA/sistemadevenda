import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/alterar_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/busca_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/endereco_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
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

  testWidgets('novo endereco carrega cidade e cep padrao', (tester) async {
    final s = ServicoDeliveryTeste();
    await tester.pumpWidget(MaterialApp(
        home: EnderecoDelivery(
      servico: s,
      cliente: '4',
    )));
    await tester.pumpAndSettle();
    expect(find.text('86.770-000'), findsOneWidget);
    expect(find.text('Santa Fe'), findsOneWidget);
    expect(find.text('PR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('busca de cliente mostra celular na lista', (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                body: TextButton(
                    onPressed: () => buscarDelivery(
                          context,
                          titulo: 'Selecionar cliente',
                          buscar: (_) async => [
                            {
                              'id': '4',
                              'nome_puro': 'Bruno Masson',
                              'celular': '44999213336',
                            }
                          ],
                          nome: (e) => e['nome_puro'].toString(),
                          detalhe: (e) => 'Celular: ${e['celular']}',
                        ),
                    child: const Text('Buscar cliente'))))));

    await tester.tap(find.text('Buscar cliente'));
    await tester.pumpAndSettle();
    expect(find.text('Bruno Masson'), findsOneWidget);
    expect(find.text('Celular: 44999213336'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
