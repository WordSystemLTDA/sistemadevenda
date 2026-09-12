import 'dart:convert';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../suporte/captura_tela.dart';
import 'card_carrinho_test.dart' show produtoCarrinho;
import 'edicao_produto_carrinho_test.dart'
    show grupo, opcao, ProdutosEdicaoTeste, ModuloEdicaoTeste;
import 'montagem_pizza_test.dart'
    show CategoriasTeste, ConfiguracoesTeste, configBigchef;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  late UsuarioProvedor usuario;
  late ProvedorCardapio cardapio;
  late ProvedorProduto produto;

  setUp(() {
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32',
          configuracoes: ConfiguracoesTeste('media', modeloBorda: 'maior')));
    cardapio = ProvedorCardapio(CategoriasTeste(), usuario)
      ..configBigchef = configBigchef()
      ..limiteSaborBordaSelecionado = 3;
    produto = ProvedorProduto(cardapio, usuario)
      ..valorVendaOriginal = 57
      ..opcoesPacotesListaFinal = [
        grupo(6, 'Selecione as Bordas',
            [opcao('Doce de Leite', '15'), opcao('Chocolate Branco', '12')]),
        grupo(
            7, 'Selecione os Adicionais', [opcao('Milho', '3', quantidade: 2)]),
      ];
  });
  tearDown(() {
    produto.dispose();
    cardapio.dispose();
    usuario.dispose();
  });

  test('borda usa sua propria permissao e divide pela quantidade selecionada',
      () {
    produto.calcularValorVenda(false, '0');
    expect(produto.calcularPrecoBorda(), 15);
    expect(produto.valorVenda, 78);
    cardapio.configBigchef = ModeloConfigBigchef.fromMap({
      ...configBigchef().toMap(),
      'modelo_valor_adicional_pizza': 'media',
    });
    produto.calcularValorVenda(false, '0');
    expect(produto.calcularPrecoBorda(), 13.5);
    expect(produto.valorVenda, 76.5);
    produto.retornarDadosPorID([6], false, '0').removeLast();
    expect(produto.calcularPrecoBorda(), 15);
    cardapio.limiteSaborBordaSelecionado = -1;
    expect(produto.calcularPrecoBorda(), 15);
    produto.retornarDadosPorID([6], false, '0').clear();
    expect(produto.calcularPrecoBorda(), 0);
  });

  for (final (modelo, total, parcelas) in [
    ('maior', 15.0, ['7.50', '7.50']),
    ('media', 13.5, ['7.50', '6.00']),
  ]) {
    test(
        'salva parcelas da borda no JSON do pedido sem dividir novamente ($modelo)',
        () {
      cardapio.configBigchef = ModeloConfigBigchef.fromMap({
        ...configBigchef().toMap(),
        'modelo_valor_adicional_pizza': modelo,
      });
      produto.calcularValorVenda(false, '0');
      final item = produtoCarrinho()
        ..valorVenda = produto.valorVenda.toStringAsFixed(2)
        ..opcoesPacotesListaFinal = produto.opcoesParaCarrinho();
      final dados = item.opcoesPacotesListaFinal!.first.dados!;
      expect(dados.map((d) => d.valor), parcelas);
      expect(dados.map((d) => d.valorOriginal), ['15.00', '12.00']);
      final corpoPedido = jsonDecode(jsonEncode({
        'produtos': [item]
      })) as Map;
      final enviado =
          jsonDecode((corpoPedido['produtos'] as List).single as String) as Map;
      final bordas = (enviado['opcoesPacotesListaFinal'] as List).first as Map;
      expect(
          (bordas['dados'] as List).map((dynamic d) => d['valor']), parcelas);
      expect(ValoresPizza.somar(item.opcoesPacotesListaFinal!.first), total);
      final copia = Modelowordprodutos.fromJson(item.toJson());
      produto.opcoesPacotesListaFinal = copia.opcoesPacotesListaFinal!;
      produto.calcularValorVenda(false, '0');
      expect(produto.valorVenda, 57 + total + 6);
      expect(produto.opcoesParaCarrinho().first.dados!.map((d) => d.valor),
          parcelas);
    });
  }

  test('rateio de tres bordas fecha centavos em media e maior', () {
    final dados = [opcao('A', '10'), opcao('B', '10'), opcao('C', '11')];
    for (final (modelo, total) in [('media', 10.33), ('maior', 11.0)]) {
      final rateio = grupo(6, 'Bordas', ValoresPizza.ratear(dados, modelo));
      expect(ValoresPizza.somar(rateio), closeTo(total, 0.000001));
      expect(ValoresPizza.ratear(rateio.dados!, modelo).map((d) => d.valor),
          rateio.dados!.map((d) => d.valor));
    }
  });

  test('editar e reabrir conserva parcelas e total sem duplicar cobranca',
      () async {
    final api = ProdutosEdicaoTeste();
    final item = api.pizza();
    final edicao = EdicaoProdutoCarrinho(
        item: item,
        servico: api,
        categorias: CategoriasTeste(),
        usuario: usuario);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    // Pizza 60 + maior borda 16 + adicionais 6.
    expect(edicao.valorUnitario, 82);
    final salvo = await edicao.concluir();
    final bordas = salvo.opcoesPacotesListaFinal!.firstWhere((o) => o.id == 6);
    expect(bordas.dados!.map((d) => d.valor), ['8.00', '8.00']);
    final reaberta = EdicaoProdutoCarrinho(
        item: salvo,
        servico: api,
        categorias: CategoriasTeste(),
        usuario: usuario);
    addTearDown(reaberta.dispose);
    await reaberta.carregar(configuracao: configBigchef());
    expect(reaberta.valorUnitario, 82);
    final borda = reaberta.opcoes.firstWhere((o) => o.id == 6);
    reaberta.produto.selecionarItem(borda.dados!.last, borda, false, '0');
    expect(reaberta.valorUnitario, 78);
    final editado = await reaberta.concluir();
    expect(
        editado.opcoesPacotesListaFinal!
            .firstWhere((o) => o.id == 6)
            .dados!
            .single
            .valor,
        '12.00');
  });

  test('carrinho antigo mostra borda cobrada e preco real da pizza', () {
    final item = produtoCarrinho()
      ..valorVenda = '72.00'
      ..opcoesPacotesListaFinal = [
        grupo(9, 'Tamanho Pizza', [opcao('G', '57')]),
        grupo(10, 'Sabores Pizza (2)',
            [opcao('Mussarela', '28.50'), opcao('Catupiry', '28.50')]),
        grupo(6, 'Selecione as Bordas',
            [opcao('Doce de Leite', '15'), opcao('Chocolate Branco', '12')]),
      ];
    expect(ValoresPizza.subtotal(item, item.opcoesPacotesListaFinal!.last), 15);
    expect(ValoresPizza.subtotal(item, item.opcoesPacotesListaFinal![1]), 57);
  });

  for (final recorrente in [false, true]) {
    for (final (largura, escala) in [
      (390.0, 1.0),
      (320.0, 2.0),
      (800.0, 1.0)
    ]) {
      testWidgets(
          'subtotais no carrinho $recorrente em $largura escala $escala',
          (tester) async {
        tester.view.physicalSize = Size(largura, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final modulo = ModuloEdicaoTeste(usuario, ProdutosEdicaoTeste());
        Modular.init(modulo);
        addTearDown(() {
          Modular.destroy();
          modulo.carrinho.dispose();
          modulo.recorrentes.dispose();
        });
        final item = produtoCarrinho()
          ..valorVenda = '78.00'
          ..opcoesPacotesListaFinal = [
            grupo(9, 'Tamanho Pizza', [opcao('G', '57')]),
            grupo(10, 'Sabores Pizza (2)', [
              ModeloDadosOpcoesPacotes(
                  id: '1',
                  nome: 'Mussarela',
                  valor: '28.50',
                  quantimaximaselecao: '1/2'),
              ModeloDadosOpcoesPacotes(
                  id: '2',
                  nome: 'Catupiry Especial',
                  valor: '28.50',
                  quantimaximaselecao: '1/2'),
            ]),
            ...produto.opcoesParaCarrinho(),
          ];
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: RepaintBoundary(
              key: const ValueKey('captura'),
              child: Scaffold(
                appBar: AppBar(title: const Text('Carrinho')),
                body: SingleChildScrollView(
                    child: recorrente
                        ? CardCarrinhoItensRecorrentes(
                            item: item,
                            index: 0,
                            idComanda: '4',
                            idComandaPedido: '104',
                            idMesa: '0',
                            value: '',
                            setarQuantidade: (_) {})
                        : CardCarrinho(
                            item: item,
                            index: 0,
                            idComanda: '4',
                            idMesa: '0',
                            value: '',
                            setarQuantidade: (_) async => true,
                            aoExcluirItem: () {})),
              )),
        ));
        await tester.tap(find.byTooltip('Mostrar detalhes'));
        await tester.pumpAndSettle();
        for (final (id, valor) in [(10, '57,00'), (6, '15,00'), (7, '6,00')]) {
          final texto =
              tester.widget<Text>(find.byKey(ValueKey('subtotal_opcao_$id')));
          expect(texto.data, contains(valor));
        }
        final total = tester
            .widget<Text>(find.byKey(const ValueKey('total_opcoes_carrinho')));
        expect(total.data, contains('78,00'));
        await capturarTela(
            tester, 'subtotais_${recorrente}_${largura}_$escala');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
