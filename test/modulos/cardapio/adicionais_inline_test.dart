import 'dart:async';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/observacoes_rapidas.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'montagem_pizza_test.dart' as fixture;

class ProdutosLentos extends fixture.ProdutosComAdicionaisTeste {
  bool falhar = false;
  Completer<Modelowordprodutos?>? pendente;
  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho) async {
    if (falhar) throw StateError('Offline');
    return pendente == null ? super.listarPorId(id, tamanho) : pendente!.future;
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  for (final (tamanho, teclado) in [
    (const Size(320, 568), 260.0),
    (const Size(393, 852), 320.0),
    (const Size(800, 900), 340.0),
  ]) {
    testWidgets('adiciona observacao com teclado aberto em $tamanho',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ObservacoesRapidas.chave: ['Cortar em 8']
      });
      final usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(
            empresa: '32', configuracoes: fixture.ConfiguracoesTeste('media')));
      final cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
      final produtos = ProdutosLentos();
      Modular.init(fixture.ModuloTeste(cardapio, usuario, produtos));
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        Modular.destroy();
        cardapio.dispose();
        usuario.dispose();
      });
      Modelowordprodutos? salvo;
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
            home: Builder(
                builder: (context) => Scaffold(
                        body: TextButton(
                      child: const Text('Produto'),
                      onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                              builder: (_) => PaginaProduto(
                                    produto: produtos.produtos.first,
                                    inserirEmItensRecorrentes: (produto) =>
                                        salvo = produto,
                                  ))),
                    )))),
      ));
      await tester.tap(find.text('Produto'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.widgetWithText(ActionChip, 'Cortar em 8'), 180,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.widgetWithText(ActionChip, 'Cortar em 8'));
      final campo = find.byKey(const Key('observacao_adicionais_produto'));
      expect(tester.widget<TextField>(campo).controller!.text, 'Cortar em 8');
      await tester.ensureVisible(campo);
      await tester.enterText(campo, 'Cortar em 8, sem sal');
      tester.view.viewInsets = FakeViewPadding(bottom: teclado);
      await tester.pumpAndSettle();
      await tester.ensureVisible(campo);
      await tester.pumpAndSettle();
      final botao = find.byKey(const Key('adicionar_produto_carrinho'));
      expect(tester.getRect(botao).bottom,
          lessThanOrEqualTo(tamanho.height - teclado));
      expect(botao.hitTestable(), findsOneWidget);
      expect(find.byTooltip('Ocultar teclado'), findsOneWidget);
      await capturarTela(tester, 'adicionais_teclado_${tamanho.width.toInt()}');
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(salvo!.observacao, 'Cortar em 8, sem sal');
      expect(
          salvo!.opcoesPacotesListaFinal!
              .where((o) => o.id == 12)
              .single
              .dados!
              .single
              .nome,
          'Cortar em 8, sem sal');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  for (final largura in [320.0, 393.0, 800.0]) {
    testWidgets(
        'pagina de adicionais permite repetir consulta e mantem linhas em $largura',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(
            empresa: '32', configuracoes: fixture.ConfiguracoesTeste('media')));
      final cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
      final produtos = ProdutosLentos()..falhar = true;
      Modular.init(fixture.ModuloTeste(cardapio, usuario, produtos));
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Modular.destroy();
        cardapio.dispose();
        usuario.dispose();
      });
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
                colorScheme:
                    ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
            home: PaginaProduto(produto: produtos.produtos.first)),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tentar novamente'), findsOneWidget);
      produtos.falhar = false;
      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aumentar Milho'));
      await tester.tap(find.byTooltip('Aumentar Bacon'));
      await tester.pumpAndSettle();
      await capturarTela(
          tester, 'etapa3_produto_adicionais_${largura.toInt()}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('fechar produto durante consulta nao atualiza widget descartado',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: fixture.ConfiguracoesTeste('media')));
    final cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
    final produtos = ProdutosLentos()
      ..pendente = Completer<Modelowordprodutos?>();
    Modular.init(fixture.ModuloTeste(cardapio, usuario, produtos));
    addTearDown(() {
      Modular.destroy();
      cardapio.dispose();
      usuario.dispose();
    });
    await tester.pumpWidget(
        MaterialApp(home: PaginaProduto(produto: produtos.produtos.first)));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    produtos.pendente!.complete(produtos.produtos.first);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
  for (final (largura, escala) in [
    (320.0, 1.0),
    (393.0, 1.0),
    (320.0, 2.0),
    (800.0, 1.3)
  ]) {
    testWidgets(
        'adicional nao desloca controles ao selecionar em $largura/$escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(
            empresa: '32', configuracoes: fixture.ConfiguracoesTeste('media')));
      final cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
      Modular.init(
          fixture.ModuloTeste(cardapio, usuario, fixture.ProdutosTeste()));
      final provedor = Modular.get<ProvedorProduto>();
      provedor.valorVendaOriginal = 57;
      provedor.opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
            id: 7, titulo: 'Adicionais', obrigatorio: false, dados: []),
      ];
      final milho =
          ModeloDadosOpcoesPacotes(id: '7', nome: 'Milho', valor: '3');
      final grupo = ModeloOpcoesPacotes(
          id: 7, titulo: 'Adicionais', obrigatorio: false, dados: [milho]);
      tester.view.physicalSize = Size(largura, 852);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        Modular.destroy();
        cardapio.dispose();
        usuario.dispose();
      });
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: Scaffold(
              body: ListenableBuilder(
                  listenable: provedor,
                  builder: (_, child) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: CardOpcoesPacotes(
                          kit: false,
                          opcoesPacote: grupo,
                          item: milho,
                          idProduto: '0')))),
        ),
      ));
      await tester.pumpAndSettle();
      final controle = find.byKey(const ValueKey('quantidade_adicional_7'));
      final card = find.byKey(const ValueKey('opcao_7_7'));
      final retangulo = tester.getRect(controle);
      final altura = tester.getSize(card).height;
      await tester.tap(find.byTooltip('Aumentar Milho'));
      await tester.pumpAndSettle();
      expect(tester.getRect(controle), retangulo);
      expect(tester.getSize(card).height, altura);
      expect(provedor.retornarDadosPorID([7], false, '0').single.quantidade, 1);
      expect(provedor.valorVenda, 60);
      await tester.tap(find.byTooltip('Aumentar Milho'));
      await tester.pumpAndSettle();
      expect(provedor.valorVenda, 63);
      expect(tester.getRect(controle), retangulo);
      await capturarTela(
          tester, 'etapa3_adicional_inline_${largura.toInt()}_$escala');
      await tester.tap(find.byTooltip('Diminuir Milho'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Diminuir Milho'));
      await tester.pumpAndSettle();
      expect(provedor.retornarDadosPorID([7], false, '0'), isEmpty);
      expect(provedor.valorVenda, 57);
      expect(tester.getRect(controle), retangulo);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('toque no card de adicional soma uma unidade', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: fixture.ConfiguracoesTeste('media')));
    final cardapio = ProvedorCardapio(fixture.CategoriasTeste(), usuario);
    Modular.init(
        fixture.ModuloTeste(cardapio, usuario, fixture.ProdutosTeste()));
    final provedor = Modular.get<ProvedorProduto>();
    provedor.valorVendaOriginal = 57;
    provedor.opcoesPacotesListaFinal = [
      ModeloOpcoesPacotes(
          id: 7, titulo: 'Adicionais', obrigatorio: false, dados: []),
    ];
    final milho = ModeloDadosOpcoesPacotes(id: '7', nome: 'Milho', valor: '3');
    final grupo = ModeloOpcoesPacotes(
        id: 7, titulo: 'Adicionais', obrigatorio: false, dados: [milho]);
    addTearDown(() {
      Modular.destroy();
      cardapio.dispose();
      usuario.dispose();
    });

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ListenableBuilder(
          listenable: provedor,
          builder: (_, child) => CardOpcoesPacotes(
            kit: false,
            opcoesPacote: grupo,
            item: milho,
            idProduto: '0',
          ),
        ),
      ),
    ));

    final card = find.byKey(const ValueKey('opcao_7_7'));
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(provedor.retornarDadosPorID([7], false, '0').single.quantidade, 1);
    expect(provedor.valorVenda, 60);

    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(provedor.retornarDadosPorID([7], false, '0').single.quantidade, 2);
    expect(provedor.valorVenda, 63);
    expect(tester.takeException(), isNull);
  });
}
