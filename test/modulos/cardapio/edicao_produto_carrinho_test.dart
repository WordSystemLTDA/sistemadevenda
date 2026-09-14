import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_categoria.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_produto_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_editar_opcoes_carrinho.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'montagem_pizza_test.dart'
    show
        ProdutosTeste,
        CategoriasTeste,
        ConfiguracoesTeste,
        configBigchef,
        sabor,
        DioClienteTeste;

class ConfigEdicaoTeste extends Fake implements ServicoConfigBigchef {
  @override
  Future<ModeloConfigBigchef?> listar({bool forcarAtualizacao = false}) async =>
      configBigchef();
}

class ModuloEdicaoTeste extends Module {
  final UsuarioProvedor usuario;
  final ProdutosEdicaoTeste api;
  late final servico = ServicosItensComanda(DioClienteTeste(), usuario);
  late final carrinho = ProvedorCarrinho(servico);
  late final recorrentes = ProvedorItensRecorrentes(servico);
  ModuloEdicaoTeste(this.usuario, this.api);

  @override
  void binds(Injector i) {
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<ServicoProduto>(api);
    i.addInstance<ServicosCategoria>(CategoriasTeste());
    i.addInstance<ServicoConfigBigchef>(ConfigEdicaoTeste());
    i.addInstance<ProvedorCarrinho>(carrinho);
    i.addInstance<ProvedorItensRecorrentes>(recorrentes);
  }
}

ModeloOpcoesPacotes grupo(
        int id, String titulo, List<ModeloDadosOpcoesPacotes> dados) =>
    ModeloOpcoesPacotes(
        id: id, titulo: titulo, obrigatorio: false, dados: dados);

ModeloDadosOpcoesPacotes opcao(String nome, String valor, {int? quantidade}) =>
    ModeloDadosOpcoesPacotes(
        id: nome, nome: nome, valor: valor, quantidade: quantidade);

class ProdutosEdicaoTeste extends ProdutosTeste {
  bool falhar = false;
  bool falharCatalogo = false;
  bool repetirPrimeiraPagina = false;
  Completer<void>? aguardar;
  Completer<void>? aguardarCatalogo;

  @override
  Future<List<Modelowordprodutos>> listarPorCategoria(
      String categoria, int pagina) async {
    consultasPorCategoria.add((categoria, pagina));
    await aguardarCatalogo?.future;
    if (falharCatalogo) throw StateError('Catálogo indisponível');
    return produtos
        .where((p) => categoria == '0' || p.categoria == categoria)
        .skip(repetirPrimeiraPagina ? 0 : (pagina - 1) * 15)
        .take(15)
        .toList();
  }

  @override
  Future<Modelowordprodutos?> listarPorId(String id, String tamanho) async {
    await aguardar?.future;
    if (falhar) throw StateError('Sem conexão');
    final produto = await super.listarPorId(id, tamanho);
    // listar_por_id.php devolve a categoria da pizza e nao inclui tamanhosPizza.
    final dados = produto!.toMap()..remove('tamanhosPizza');
    dados['nome'] = produto.nomeCategoria;
    return Modelowordprodutos.fromMap(dados)
      ..opcoesPacotes = [
        grupo(6, 'Bordas', [opcao('Cheddar', '12'), opcao('Catupiry', '16')]),
        grupo(7, 'Adicionais', [
          opcao('Milho', '3', quantidade: 1),
          opcao('Bacon', '4', quantidade: 1)
        ]),
        grupo(8, 'Itens para retirar',
            [opcao('Cebola', '0'), opcao('Azeitona', '0')]),
      ];
  }

  Modelowordprodutos pizza({bool maior = false}) =>
      Modelowordprodutos.fromMap(produtos.first.toMap())
        ..quantidade = 2
        ..valorVenda = maior ? '92.00' : '80.00'
        ..observacao = 'Bem assada'
        ..limiteSaboresBorda = 2
        ..opcoesPacotesListaFinal = [
          grupo(9, 'Tamanho Pizza', [opcao('G', maior ? '70' : '60')]),
          grupo(10, 'Sabores Pizza (2)', [
            for (final (nome, valor) in [
              ('Mussarela', '25'),
              ('Calabresa especial', '35')
            ])
              ModeloDadosOpcoesPacotes(
                  id: nome,
                  nome: nome,
                  valor: valor,
                  codigo: nome,
                  imprimirCodigoProdutoPreparo: 'Sim',
                  quantimaximaselecao: '1/2'),
          ]),
          grupo(6, 'Bordas', [opcao('Cheddar', '12'), opcao('Catupiry', '16')]),
          grupo(7, 'Adicionais', [opcao('Milho', '3', quantidade: 2)]),
          grupo(8, 'Itens para retirar', [opcao('Cebola', '0')]),
          ModeloOpcoesPacotes(
              id: 11,
              titulo: 'Observação',
              tipo: 7,
              obrigatorio: false,
              dados: [opcao('Bem assada', '0')]),
        ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(carregarFontesDeTeste);
  late ProdutosEdicaoTeste api;
  late UsuarioProvedor usuario;

  setUp(() {
    api = ProdutosEdicaoTeste();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(
          empresa: '32', configuracoes: ConfiguracoesTeste('media')));
  });
  tearDown(() => usuario.dispose());

  EdicaoProdutoCarrinho criar(Modelowordprodutos item) => EdicaoProdutoCarrinho(
      item: item,
      servico: api,
      categorias: CategoriasTeste(),
      usuario: usuario);

  test('abrir e salvar conserva preco, quantidade, bordas e observacao',
      () async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    expect(edicao.erro, isNull);
    expect(edicao.alterado, isFalse);
    expect(edicao.valorUnitario, 80);
    expect(edicao.total, 160);
    final salvo = await edicao.concluir();
    expect(salvo.quantidade, 2);
    expect(salvo.valorVenda, '80.00');
    expect(salvo.observacao, 'Bem assada');
    expect(salvo.limiteSaboresBorda, 2);
    expect(
        salvo.opcoesPacotesListaFinal!.where((o) => o.tipo == 7), hasLength(1));
    expect(jsonEncode(item.toMap()), antes);
  });

  test(
      'API sem tamanhos e com nome da categoria usa sabores por ID em todas as paginas',
      () async {
    final item = api.pizza();
    final sabores = api.produtos.toList();
    final nomes = ['Mussarela', 'Catupiry Especial', 'Dois Quijos'];
    for (var i = 0; i < sabores.length; i++) {
      sabores[i]
        ..id = '${305 + i}'
        ..codigo = '${i + 1}'
        ..nome = nomes[i]
        ..categoria = 'Queijos'
        ..nomeCategoria = 'Pizza de Queijos'
        ..imprimirCodigoProdutoPreparo = 'Sim';
    }
    item
      ..id = sabores.first.id
      ..codigo = sabores.first.codigo
      ..nome = 'Pizza de Queijos'
      ..tamanhosPizza = null;
    final selecionados =
        item.opcoesPacotesListaFinal!.firstWhere((o) => o.id == 10).dados!;
    for (var i = 0; i < selecionados.length; i++) {
      selecionados[i] = ModeloDadosOpcoesPacotes.fromMap({
        ...selecionados[i].toMap(),
        'id': sabores[i].id,
        'codigo': sabores[i].codigo,
        'nome': sabores[i].nome,
      });
    }
    api.produtos.insertAll(
        0, [for (var i = 0; i < 15; i++) sabor('Outro $i', 'Queijos', '40')]);
    final antes = jsonEncode(item.toMap());
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    expect(edicao.erro, isNull);
    expect(api.consultasPorCategoria, [('Queijos', 1), ('Queijos', 2)]);
    expect(api.consultasPorId, [('305', 'G')]);
    expect(edicao.cardapio.saboresPizzaSelecionados.map((p) => p.nome),
        ['Mussarela', 'Catupiry Especial']);
    expect(edicao.valorUnitario, 80);
    edicao.selecionarSabor(sabores.first);
    edicao.selecionarSabor(sabores.last);
    final salvo = await edicao.concluir();
    expect(salvo.id, '306');
    expect(salvo.codigo, '2');
    expect(salvo.imprimirCodigoProdutoPreparo, 'Sim');
    expect(salvo.tamanhosPizza!.map((t) => t.id), ['P', 'G']);
    expect(salvo.valorVenda, '100.00');
    final saboresSalvos =
        salvo.opcoesPacotesListaFinal!.firstWhere((o) => o.id == 10).dados!;
    expect(
        saboresSalvos.map((p) => p.nome), ['Catupiry Especial', 'Dois Quijos']);
    expect(saboresSalvos.map((p) => p.codigo), ['2', '3']);
    expect(saboresSalvos.map((p) => p.imprimirCodigoProdutoPreparo),
        ['Sim', 'Sim']);
    expect(saboresSalvos.map((p) => p.valor), ['35.00', '45.00']);
    expect(saboresSalvos.map((p) => p.quantimaximaselecao), ['1/2', '1/2']);
    expect(jsonEncode(item.toMap()), antes);
    final reaberta = criar(salvo);
    addTearDown(reaberta.dispose);
    await reaberta.carregar(configuracao: configBigchef());
    expect(reaberta.erro, isNull);
    expect((await reaberta.concluir()).valorVenda, '100.00');
  });

  test('tamanho ausente no catalogo impede salvar sem alterar o carrinho',
      () async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    api.produtos.first.tamanhosPizza!.removeWhere((t) => t.id == 'G');
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    expect(edicao.erro, isNotNull);
    await expectLater(edicao.concluir(), throwsStateError);
    expect(jsonEncode(item.toMap()), antes);
  });

  test('pagina repetida da API nao deixa carregamento em loop', () async {
    final item = api.pizza();
    api.produtos.insertAll(
        0, [for (var i = 0; i < 15; i++) sabor('Outro $i', 'Queijos', '40')]);
    api.repetirPrimeiraPagina = true;
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    expect(edicao.erro, isNotNull);
    expect(edicao.carregando, isFalse);
    expect(api.consultasPorCategoria, [('Queijos', 1), ('Queijos', 2)]);
    await expectLater(edicao.concluir(), throwsStateError);
  });

  test('edita borda, adicional, retirada e observacao em copia independente',
      () async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    final borda = edicao.opcoes.firstWhere((o) => o.id == 6);
    edicao.produto.selecionarItem(borda.dados!.last, borda, false, '0');
    edicao.produto.retornarDadosPorID([7], false, '0').single.quantidade = 3;
    final retirada = edicao.opcoes.firstWhere((o) => o.id == 8);
    edicao.produto.selecionarItem(retirada.dados!.first, retirada, false, '0');
    edicao.observacao = 'Cortar em 8 pedaços';
    expect(edicao.alterado, isTrue);
    expect(edicao.valorUnitario, 81);
    final salvo = await edicao.concluir();
    final dados = salvo.opcoesPacotesListaFinal!;
    expect(dados.firstWhere((o) => o.id == 6).dados!.single.nome, 'Cheddar');
    expect(dados.firstWhere((o) => o.id == 7).dados!.single.quantidade, 3);
    expect(dados.firstWhere((o) => o.id == 8).dados, isEmpty);
    expect(dados.where((o) => o.tipo == 7).single.dados!.single.nome,
        'Cortar em 8 pedaços');
    expect(jsonEncode(item.toMap()), antes);
    final reaberta = criar(salvo);
    addTearDown(reaberta.dispose);
    await reaberta.carregar(configuracao: configBigchef());
    expect(reaberta.valorUnitario, 81);
    expect(reaberta.cardapio.limiteSaborBordaSelecionado, 2);
    expect((await reaberta.concluir()).valorVenda, '81.00');
  });

  for (final maior in [false, true]) {
    test(
        'troca sabores recalcula preco e dados de preparo (${maior ? 'maior' : 'media'})',
        () async {
      usuario.setUsuario(UsuarioModelo(
          empresa: '32',
          configuracoes: ConfiguracoesTeste(maior ? 'maior' : 'media')));
      final edicao = criar(api.pizza(maior: maior));
      addTearDown(edicao.dispose);
      await edicao.carregar(configuracao: configBigchef());
      edicao.selecionarSabor(api.produtos.first);
      edicao.selecionarSabor(api.produtos.last);
      final salvo = await edicao.concluir();
      expect(salvo.id, 'Calabresa especial');
      expect(salvo.codigo, 'Calabresa especial');
      expect(salvo.valorVenda, maior ? '112.00' : '100.00');
      final sabores =
          salvo.opcoesPacotesListaFinal!.firstWhere((o) => o.id == 10).dados!;
      expect(sabores.map((d) => d.nome), ['Calabresa especial', 'Chocolate']);
      expect(sabores.map((d) => d.quantimaximaselecao), ['1/2', '1/2']);
      expect(sabores.map((d) => d.valor),
          maior ? ['45.00', '45.00'] : ['35.00', '45.00']);
      expect(salvo.quantidade, 2);
    });
  }

  test('valida pizza sem sabores e permite remover observacao', () async {
    final edicao = criar(api.pizza());
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    edicao.observacao = '';
    final salvo = await edicao.concluir();
    expect(salvo.observacao, isEmpty);
    expect(salvo.opcoesPacotesListaFinal!.where((o) => o.tipo == 7), isEmpty);
    for (final sabor in edicao.cardapio.saboresPizzaSelecionados.toList()) {
      edicao.selecionarSabor(sabor);
    }
    expect(edicao.validar(), isNotNull);
    await expectLater(edicao.concluir(), throwsStateError);
  });

  test('erro no carregamento permite tentar novamente sem alterar o item',
      () async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    api.falhar = true;
    await edicao.carregar(configuracao: configBigchef());
    expect(edicao.erro, isNotNull);
    expect(edicao.carregando, isFalse);
    api.falhar = false;
    await edicao.carregar(configuracao: configBigchef());
    expect(edicao.erro, isNull);
    expect(jsonEncode(item.toMap()), antes);
  });

  test('produto comum conserva preco e quantidade ao alterar adicionais',
      () async {
    final item = api.pizza()
      ..habilTipo = 'Normal'
      ..valorVenda = '26.00';
    item.opcoesPacotesListaFinal!.removeWhere((o) => [9, 10, 6].contains(o.id));
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar();
    expect(edicao.pizza, isFalse);
    expect(edicao.valorUnitario, 26);
    edicao.produto.retornarDadosPorID([7], false, '0').single.quantidade = 3;
    edicao.produto.calcularValorVenda(false, '0');
    final salvo = await edicao.concluir();
    expect(salvo.valorVenda, '29.00');
    expect(salvo.quantidade, 2);
    expect(salvo.opcoesPacotesListaFinal!.where((o) => o.id == 10), isEmpty);
  });

  test(
      'rascunhos das etapas so alteram o resumo ao salvar e nao se compartilham',
      () async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    final edicao = criar(item);
    addTearDown(edicao.dispose);
    await edicao.carregar(configuracao: configBigchef());
    edicao.observacao = 'Observação do resumo';
    final rascunho = edicao.criarRascunho();
    addTearDown(rascunho.dispose);
    expect(rascunho.alterado, isFalse);
    rascunho.produto.retornarDadosPorID([7], false, '0').single.quantidade = 3;
    rascunho.produto.calcularValorVenda(false, '0');
    rascunho.selecionarSabor(api.produtos.first);
    rascunho.selecionarSabor(api.produtos.last);
    expect(edicao.valorUnitario, 80);
    expect(edicao.cardapio.saboresPizzaSelecionados.first.nome, 'Mussarela');
    edicao.aplicarRascunho(rascunho);
    expect(edicao.valorUnitario, 103);
    expect(edicao.observacao, 'Observação do resumo');
    expect(edicao.alterado, isTrue);
    rascunho.produto.retornarDadosPorID([7], false, '0').single.quantidade = 9;
    expect(edicao.produto.retornarDadosPorID([7], false, '0').single.quantidade,
        3);
    final proximaEtapa = edicao.criarRascunho();
    addTearDown(proximaEtapa.dispose);
    expect(proximaEtapa.alterado, isFalse);
    expect(proximaEtapa.valorUnitario, 103);
    expect((await edicao.concluir()).valorVenda, '103.00');
    expect(jsonEncode(item.toMap()), antes);
  });

  test('fechar durante carregamento nao notifica provedor descartado',
      () async {
    api.aguardar = Completer<void>();
    final edicao = criar(api.pizza());
    final carregamento = edicao.carregar(configuracao: configBigchef());
    edicao.dispose();
    api.aguardar!.complete();
    await carregamento;
  });

  test('fechar durante consulta ao catalogo nao altera o item nem notifica',
      () async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    api.aguardarCatalogo = Completer<void>();
    final edicao = criar(item);
    final carregamento = edicao.carregar(configuracao: configBigchef());
    while (api.consultasPorCategoria.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    edicao.dispose();
    api.aguardarCatalogo!.complete();
    await carregamento;
    expect(jsonEncode(item.toMap()), antes);
  });

  Future<void> abrirEditor(WidgetTester tester, EdicaoProdutoCarrinho edicao,
      Future<bool> Function(Modelowordprodutos) salvar) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(colorSchemeSeed: const Color(0xFF67538A)),
      builder: (context, child) =>
          RepaintBoundary(key: const ValueKey('captura'), child: child!),
      home: Scaffold(
          body: Builder(
              builder: (context) => TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                            builder: (_) => PaginaEditarProdutoCarrinho(
                                edicao: edicao,
                                carregarConfiguracao: () async =>
                                    configBigchef(),
                                aoSalvar: salvar))),
                    child: const Text('Abrir edição'),
                  ))),
    ));
    await tester.tap(find.text('Abrir edição'));
    await tester.pumpAndSettle();
  }

  Future<void> mostrar(WidgetTester tester, Finder alvo) async {
    final rolagem = find
        .descendant(
            of: find.byType(ListView).first, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(alvo, 150, scrollable: rolagem);
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(alvo), alignment: 0.3);
    await tester.pumpAndSettle();
  }

  testWidgets('falha no catalogo permite tentar novamente e abrir a edicao',
      (tester) async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    api.falharCatalogo = true;
    final edicao = criar(item);
    await abrirEditor(tester, edicao, (_) async => true);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.byKey(const Key('salvar_edicao_produto')), findsNothing);
    api.falharCatalogo = false;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Sabores da pizza (2)'), findsOneWidget);
    expect(find.byKey(const Key('salvar_edicao_produto')), findsOneWidget);
    expect(jsonEncode(item.toMap()), antes);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor permite trocar sabores e salvar a pizza atualizada',
      (tester) async {
    final edicao = criar(api.pizza());
    Modelowordprodutos? salvo;
    await abrirEditor(tester, edicao, (p) async {
      salvo = p;
      return true;
    });
    await tester.tap(find.byTooltip('Alterar tamanho e sabores'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sabor_edicao_Mussarela')));
    await tester.pumpAndSettle();
    expect(find.text('Salvar (1)'), findsOneWidget);
    expect(find.byType(CardProduto), findsWidgets);
    expect(find.byType(ListaTamanhosPizza), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Chocolate');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sabor_edicao_Chocolate')));
    await tester.pumpAndSettle();
    expect(edicao.cardapio.saboresPizzaSelecionados.map((s) => s.nome),
        ['Mussarela', 'Calabresa especial']);
    expect(salvo, isNull);
    await tester.tap(find.text('Salvar (2)'));
    await tester.pumpAndSettle();
    expect(find.text('(1/2) Chocolate'), findsOneWidget);
    expect(find.text(200.0.obterReal()), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar_edicao_produto')));
    await tester.pumpAndSettle();
    expect(salvo!.id, 'Calabresa especial');
    expect(salvo!.valorVenda, '100.00');
    expect(tester.takeException(), isNull);
  });

  testWidgets('seletor permite trocar tamanho da pizza na edicao',
      (tester) async {
    final edicao = criar(api.pizza());
    Modelowordprodutos? salvo;
    await abrirEditor(tester, edicao, (p) async {
      salvo = p;
      return true;
    });
    await tester.tap(find.byKey(const Key('alterar_sabores_pizza')));
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: find.byType(ListaTamanhosPizza), matching: find.text('P')),
        findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(ListaTamanhosPizza), matching: find.text('G')),
        findsOneWidget);
    await tester.tap(find
        .descendant(
            of: find.byType(ListaTamanhosPizza), matching: find.text('P'))
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Salvar (0)'), findsOneWidget);
    expect(find.text('Selecione os sabores disponíveis para esse tamanho.'),
        findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
    await mostrar(tester, find.byKey(const ValueKey('sabor_edicao_Chocolate')));
    await tester.tap(find.byKey(const ValueKey('sabor_edicao_Chocolate')));
    await tester.pumpAndSettle();
    expect(find.text('Salvar (1)'), findsOneWidget);
    expect(find.text(100.0.obterReal()), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(find.text('Pizza P'), findsOneWidget);
    expect(find.text('Sabores da pizza (1)'), findsOneWidget);
    expect(find.text('(1/1) Chocolate'), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar_edicao_produto')));
    await tester.pumpAndSettle();
    final tamanho = salvo!.opcoesPacotesListaFinal!
        .firstWhere((opcao) => opcao.id == 9)
        .dados!
        .single;
    final sabor = salvo!.opcoesPacotesListaFinal!
        .firstWhere((opcao) => opcao.id == 10)
        .dados!
        .single;
    expect(tamanho.id, 'P');
    expect(tamanho.valor, '30.00');
    expect(sabor.nome, 'Chocolate');
    expect(sabor.quantimaximaselecao, '1/1');
    expect(sabor.valor, '30.00');
    expect(salvo!.valorVenda, '50.00');
    expect(api.consultasPorId, contains(('Chocolate', 'P')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'bordas, adicionais e retiradas salvam em suas telas antes do resumo',
      (tester) async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    final edicao = criar(item);
    Modelowordprodutos? salvo;
    await abrirEditor(tester, edicao, (produto) async {
      salvo = produto;
      return true;
    });
    await tester.tap(find.byTooltip('Editar bordas'));
    await tester.pumpAndSettle();
    expect(find.byType(ListaBordas), findsOneWidget);
    expect(find.text('Salvar (2)'), findsOneWidget);
    final umSabor = find.descendant(
        of: find.byType(ListaBordas), matching: find.text('1 sabor'));
    await tester.tap(umSabor);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Desmarque uma borda antes de diminuir a quantidade de sabores.'),
        findsOneWidget);
    final catupiry = find.byKey(const ValueKey('opcao_6_Catupiry'));
    await mostrar(tester, catupiry);
    await tester.tap(catupiry);
    await tester.pumpAndSettle();
    await tester.tap(umSabor);
    await tester.pumpAndSettle();
    expect(find.text('Salvar (1)'), findsOneWidget);
    expect(edicao.cardapio.limiteSaborBordaSelecionado, 2);
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(edicao.cardapio.limiteSaborBordaSelecionado, 1);
    expect(edicao.valorUnitario, 78);
    expect(find.text('Bordas (1)'), findsOneWidget);
    expect(salvo, isNull);
    await mostrar(tester, find.byKey(const ValueKey('abrir_edicao_opcao_7')));
    await tester.tap(find.byKey(const ValueKey('abrir_edicao_opcao_7')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar Milho'));
    await tester.pumpAndSettle();
    expect(edicao.valorUnitario, 78);
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(find.text('3x Milho'), findsOneWidget);
    expect(edicao.valorUnitario, 81);
    await mostrar(tester, find.byKey(const ValueKey('abrir_edicao_opcao_8')));
    await tester.tap(find.byKey(const ValueKey('abrir_edicao_opcao_8')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cebola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Azeitona'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(edicao.produto.retornarDadosPorID([8], false, '0').single.nome,
        'Azeitona');
    expect(salvo, isNull);
    expect(jsonEncode(item.toMap()), antes);
    await tester.tap(find.byKey(const Key('salvar_edicao_produto')));
    await tester.pumpAndSettle();
    expect(salvo!.valorVenda, '81.00');
    expect(salvo!.quantidade, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('categorias e busca conservam sabores marcados fora do filtro',
      (tester) async {
    final edicao = criar(api.pizza());
    await abrirEditor(tester, edicao, (_) async => true);
    await tester.tap(find.byKey(const Key('alterar_sabores_pizza')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Doces'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('sabor_edicao_Chocolate')), findsOneWidget);
    expect(find.byKey(const ValueKey('sabor_edicao_Mussarela')), findsNothing);
    expect(find.text('Salvar (2)'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Chocolate');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('sabor_edicao_Chocolate')), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.text('Todos'));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('sabor_edicao_Mussarela')), findsOneWidget);
    expect(find.text('Salvar (2)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(edicao.alterado, isFalse);
    expect(edicao.valorUnitario, 80);
    expect(tester.takeException(), isNull);
  });

  testWidgets('permite salvar sem adicionais mas impede pizza sem sabores',
      (tester) async {
    final edicao = criar(api.pizza());
    await abrirEditor(tester, edicao, (_) async => true);
    await tester.tap(find.byKey(const Key('alterar_sabores_pizza')));
    await tester.pumpAndSettle();
    for (final nome in ['Mussarela', 'Calabresa especial']) {
      await tester.tap(find.byKey(ValueKey('sabor_edicao_$nome')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Salvar (0)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(
        find.text('Selecione pelo menos um sabor de pizza.'), findsOneWidget);
    expect(find.byType(PaginaEditarOpcoesCarrinho), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    await mostrar(tester, find.byKey(const ValueKey('abrir_edicao_opcao_7')));
    await tester.tap(find.byKey(const ValueKey('abrir_edicao_opcao_7')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Milho'));
    await tester.pumpAndSettle();
    expect(find.text('Salvar (0)'), findsOneWidget);
    await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
    await tester.pumpAndSettle();
    expect(find.text('Adicionais (0)'), findsOneWidget);
    expect(edicao.valorUnitario, 74);
    expect(edicao.cardapio.saboresPizzaSelecionados.length, 2);
    expect(tester.takeException(), isNull);
  });

  for (final idOpcao in [null, 6, 7, 8]) {
    testWidgets('voltar sem salvar descarta somente a etapa $idOpcao',
        (tester) async {
      final edicao = criar(api.pizza());
      await abrirEditor(tester, edicao, (_) async => true);
      await mostrar(tester, find.byKey(const Key('observacao_edicao_produto')));
      await tester.enterText(
          find.byKey(const Key('observacao_edicao_produto')), 'Bem quente');
      final botao = idOpcao == null
          ? find.byKey(const Key('alterar_sabores_pizza'))
          : find.byKey(ValueKey('abrir_edicao_opcao_$idOpcao'));
      await mostrar(tester, botao);
      await tester.tap(botao);
      await tester.pumpAndSettle();
      final alvo = switch (idOpcao) {
        6 => find.text('Catupiry'),
        7 => find.text('Bacon'),
        8 => find.text('Azeitona'),
        _ => find.byKey(const ValueKey('sabor_edicao_Mussarela')),
      };
      await tester.tap(alvo);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações desta etapa?'), findsOneWidget);
      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(PaginaEditarOpcoesCarrinho), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(PaginaEditarOpcoesCarrinho), findsNothing);
      expect(edicao.valorUnitario, 80);
      expect(edicao.observacao, 'Bem quente');
      expect(edicao.cardapio.saboresPizzaSelecionados.length, 2);
      expect(edicao.produto.retornarDadosPorID([6], false, '0').length, 2);
      expect(edicao.produto.retornarDadosPorID([7], false, '0').single.nome,
          'Milho');
      expect(edicao.produto.retornarDadosPorID([8], false, '0').single.nome,
          'Cebola');
      expect(tester.takeException(), isNull);
    });
  }

  for (final recorrente in [false, true]) {
    testWidgets(
        'botao do carrinho edita sem inserir novo item (recorrente: $recorrente)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final modulo = ModuloEdicaoTeste(usuario, api);
      Modular.init(modulo);
      addTearDown(() {
        modulo.carrinho.dispose();
        modulo.recorrentes.dispose();
        Modular.destroy();
      });
      await modulo.carrinho.selecionarAtendimento(
          tipo: 'comanda', idAtendimento: '104', idRecurso: '4');
      modulo.recorrentes.selecionarAtendimento(
          tipo: 'comanda', idAtendimento: '104', idRecurso: '4');
      await modulo.servico.armazenamento.alterar(
          modulo.carrinho.contexto!, (itens) => itens.add(api.pizza()),
          recorrentes: recorrente);
      await modulo.carrinho.listarComandasPedidos();
      await modulo.recorrentes.listarComandasPedidos('104');
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: ListenableBuilder(
        listenable: recorrente ? modulo.recorrentes : modulo.carrinho,
        builder: (context, _) {
          final item = recorrente
              ? modulo.recorrentes.itensCarrinho.single
              : modulo.carrinho.itensCarrinho.listaComandosPedidos.single;
          return SingleChildScrollView(
              child: recorrente
                  ? CardCarrinhoItensRecorrentes(
                      item: item,
                      index: 0,
                      idComanda: '4',
                      idComandaPedido: '104',
                      idMesa: '0',
                      value: null,
                      setarQuantidade: (_) {},
                    )
                  : CardCarrinho(
                      item: item,
                      index: 0,
                      idComanda: '4',
                      idMesa: '0',
                      value: null,
                      setarQuantidade: (_) async => true,
                      aoExcluirItem: () {}));
        },
      ))));
      await tester.tap(find.text('Editar Produto'));
      await tester.pumpAndSettle();
      await mostrar(tester, find.byKey(const ValueKey('abrir_edicao_opcao_7')));
      await tester.tap(find.byKey(const ValueKey('abrir_edicao_opcao_7')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bacon'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
      await tester.pumpAndSettle();
      final antesDeSalvar = await modulo.servico.armazenamento
          .listar(modulo.carrinho.contexto!, recorrentes: recorrente);
      expect(antesDeSalvar.single.valorVenda, '80.00');
      await mostrar(tester, find.byKey(const Key('observacao_edicao_produto')));
      await tester.enterText(
          find.byKey(const Key('observacao_edicao_produto')), 'Pouco sal');
      await tester.tap(find.byKey(const Key('salvar_edicao_produto')));
      await tester.pumpAndSettle();
      final itens = await modulo.servico.armazenamento
          .listar(modulo.carrinho.contexto!, recorrentes: recorrente);
      expect(itens, hasLength(1));
      expect(itens.single.observacao, 'Pouco sal');
      expect(itens.single.valorVenda, '84.00');
      expect(itens.single.quantidade, 2);
      expect(find.text('Editar Produto'), findsOneWidget);
      expect(find.text('Produto atualizado no carrinho.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (largura, escala) in [
    (320.0, 1.0),
    (390.0, 1.0),
    (320.0, 2.0),
    (900.0, 1.0)
  ]) {
    testWidgets('edicao responsiva ${largura}_$escala com selecoes e total',
        (tester) async {
      tester.view.physicalSize = Size(largura, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final edicao = criar(api.pizza());
      Modelowordprodutos? salvo;
      await abrirEditor(tester, edicao, (produto) async {
        salvo = produto;
        return true;
      });
      expect(find.text('Sabores da pizza (2)'), findsOneWidget);
      expect(find.text(160.0.obterReal()), findsOneWidget);
      await capturarTela(tester, 'editar_produto_${largura}_$escala');
      await mostrar(tester, find.byKey(const Key('alterar_sabores_pizza')));
      await tester.tap(find.byKey(const Key('alterar_sabores_pizza')));
      await tester.pumpAndSettle();
      await capturarTela(tester, 'editar_sabores_${largura}_$escala');
      expect(find.text('Salvar (2)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await mostrar(tester, find.byKey(const ValueKey('abrir_edicao_opcao_6')));
      await tester.tap(find.byKey(const ValueKey('abrir_edicao_opcao_6')));
      await tester.pumpAndSettle();
      await capturarTela(tester, 'editar_bordas_${largura}_$escala');
      expect(find.byType(ListaBordas), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await mostrar(tester, find.byKey(const ValueKey('abrir_edicao_opcao_8')));
      await tester.tap(find.byKey(const ValueKey('abrir_edicao_opcao_8')));
      await tester.pumpAndSettle();
      await capturarTela(tester, 'editar_retiradas_${largura}_$escala');
      expect(find.text('Salvar (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await mostrar(tester, find.text('Adicionais (1)'));
      await tester.tap(find.text('Adicionais (1)'));
      await tester.pumpAndSettle();
      await mostrar(tester, find.byKey(const ValueKey('editar_7_Bacon')));
      await tester.tap(find.text('Bacon'));
      await tester.pumpAndSettle();
      expect(find.text('Salvar (2)'), findsOneWidget);
      expect(find.text(168.0.obterReal()), findsOneWidget);
      await capturarTela(tester, 'editar_adicionais_${largura}_$escala');
      expect(tester.takeException(), isNull);
      expect(edicao.valorUnitario, 80);
      expect(salvo, isNull);
      await tester.tap(find.byKey(const Key('salvar_etapa_produto')));
      await tester.pumpAndSettle();
      expect(find.text('Adicionais (2)'), findsOneWidget);
      expect(edicao.valorUnitario, 84);
      await tester.tap(find.byKey(const Key('salvar_edicao_produto')));
      await tester.pumpAndSettle();
      expect(salvo!.valorVenda, '84.00');
      expect(find.text('Abrir edição'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final (tamanho, escala, teclado) in [
    (const Size(320, 568), 1.0, 250.0),
    (const Size(390, 844), 1.0, 320.0),
    (const Size(320, 844), 2.0, 300.0),
  ]) {
    testWidgets(
        'salva observacao com teclado aberto em $tamanho e fonte $escala',
        (tester) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = escala;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      Modelowordprodutos? salvo;
      var chamadas = 0;
      await abrirEditor(tester, criar(api.pizza()), (produto) async {
        chamadas++;
        salvo = produto;
        return true;
      });
      final campo = find.byKey(const Key('observacao_edicao_produto'));
      await mostrar(tester, campo);
      await tester.enterText(campo, 'Bem assada, cortar em 8');
      tester.view.viewInsets = FakeViewPadding(bottom: teclado);
      await tester.pumpAndSettle();

      final salvar = find.byKey(const Key('salvar_edicao_produto'));
      final areaSalvar = tester.getRect(salvar);
      expect(areaSalvar.bottom, lessThanOrEqualTo(tamanho.height - teclado));
      expect(tester.getRect(campo).bottom, lessThanOrEqualTo(areaSalvar.top));
      expect(salvar.hitTestable(), findsOneWidget);
      expect(tester.widget<TextField>(campo).focusNode!.hasFocus, isTrue);
      await capturarTela(tester,
          'editar_produto_teclado_${tamanho.width}_${tamanho.height}_$escala');

      await tester.tap(salvar);
      await tester.pumpAndSettle();
      expect(chamadas, 1);
      expect(salvo!.observacao, 'Bem assada, cortar em 8');
      expect(find.text('Abrir edição'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('fecha teclado pelo botao, pela tecla concluir e pelo toque fora',
      (tester) async {
    var chamadas = 0;
    final edicao = criar(api.pizza());
    await abrirEditor(tester, edicao, (_) async {
      chamadas++;
      return true;
    });
    final campo = find.byKey(const Key('observacao_edicao_produto'));
    await mostrar(tester, campo);
    await tester.enterText(campo, 'Sem cebola');
    await tester.pumpAndSettle();
    final foco = tester.widget<TextField>(campo).focusNode!;
    expect(foco.hasFocus, isTrue);
    await tester.tap(find.byTooltip('Fechar teclado'));
    await tester.pumpAndSettle();
    expect(foco.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.showKeyboard(campo);
    await tester.pumpAndSettle();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(foco.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.showKeyboard(campo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Observação'));
    await tester.pumpAndSettle();
    expect(foco.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(edicao.observacao, 'Sem cebola');
    expect(chamadas, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'cancelar edicao descarta rascunho e salvar com erro permite tentar novamente',
      (tester) async {
    final item = api.pizza();
    final antes = jsonEncode(item.toMap());
    var chamadas = 0;
    final edicao = criar(item);
    await abrirEditor(tester, edicao, (_) async => ++chamadas > 1);
    await mostrar(tester, find.byKey(const Key('observacao_edicao_produto')));
    await tester.enterText(
        find.byKey(const Key('observacao_edicao_produto')), 'Sem sal');
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Descartar alterações?'), findsOneWidget);
    await tester.tap(find.text('Continuar editando'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('salvar_edicao_produto')));
    await tester.pumpAndSettle();
    expect(find.text('Editar Produto'), findsOneWidget);
    expect(chamadas, 1);
    expect(jsonEncode(item.toMap()), antes);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(find.text('Abrir edição'), findsOneWidget);
    expect(jsonEncode(item.toMap()), antes);
    expect(tester.takeException(), isNull);
  });
}
