import 'dart:async';

import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/edicao_produto_carrinho.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class PaginaEditarOpcoesCarrinho extends StatefulWidget {
  final EdicaoProdutoCarrinho rascunho;
  final int? idOpcao;

  const PaginaEditarOpcoesCarrinho({
    super.key,
    required this.rascunho,
    this.idOpcao,
  });

  @override
  State<PaginaEditarOpcoesCarrinho> createState() =>
      _PaginaEditarOpcoesCarrinhoState();
}

class _PaginaEditarOpcoesCarrinhoState
    extends State<PaginaEditarOpcoesCarrinho> {
  EdicaoProdutoCarrinho get edicao => widget.rascunho;
  bool get sabores => widget.idOpcao == null;
  ModeloOpcoesPacotes get opcao =>
      edicao.opcoes.firstWhere((o) => o.id == widget.idOpcao);
  final _busca = TextEditingController();
  final _rolagem = ScrollController();
  Timer? _debounce;
  String _categoria = '0';
  bool _permitirSair = false;
  late final _categorias = [
    ModeloCategoria(id: '0', nomeCategoria: 'Todos', quantidadeProdutos: '0'),
    ...edicao.cardapio.categorias
        .where((c) => c.id != '0' && (c.tamanhosPizza?.isNotEmpty ?? false)),
  ];
  late final _tamanhosPizza = _montarTamanhosPizza();

  @override
  void initState() {
    super.initState();
    if (sabores) edicao.pesquisa.listarProdutosPorCategoria(_categoria);
  }

  void _avisar(String mensagem) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(mensagem)));
  }

  void _buscar(String texto) {
    _debounce?.cancel();
    edicao.pesquisa.prepararPesquisa(texto);
    _debounce = Timer(const Duration(milliseconds: 300), _carregarPesquisa);
  }

  void _carregarPesquisa() {
    if (_busca.text.trim().isEmpty) {
      edicao.pesquisa.listarProdutosPorCategoria(_categoria);
    } else {
      edicao.pesquisa.listarProdutosPorNome(_busca.text, _categoria, '0');
    }
  }

  Future<void> _salvar() async {
    if (_permitirSair) return;
    if (sabores && edicao.cardapio.saboresPizzaSelecionados.isEmpty) {
      _avisar('Selecione pelo menos um sabor de pizza.');
      return;
    }
    if (!sabores &&
        (opcao.obrigatorio || [4, 11].contains(opcao.id)) &&
        edicao.produto.retornarDadosPorID([opcao.id], false, '0').isEmpty) {
      _avisar('Confira a seleção: ${opcao.titulo}.');
      return;
    }
    FeedbackUsuario.selecaoAlterada();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _permitirSair = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _confirmarSaida() async {
    final descartar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações desta etapa?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuar editando')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Descartar')),
        ],
      ),
    );
    if (!mounted || descartar != true) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => _permitirSair = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, false);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.dispose();
    _rolagem.dispose();
    super.dispose();
  }

  List<ModeloTamanhosPizza> _montarTamanhosPizza() {
    final porId = <String, ModeloTamanhosPizza>{};
    for (final categoria in edicao.cardapio.categorias) {
      if (categoria.id == '0') continue;
      for (final tamanho
          in categoria.tamanhosPizza ?? <ModeloTamanhosPizza>[]) {
        porId.putIfAbsent(tamanho.id, () => tamanho);
      }
    }
    final atual = edicao.cardapio.tamanhosPizza;
    if (atual != null) porId.putIfAbsent(atual.id, () => atual);
    return porId.values.toList();
  }

  void _selecionarTamanho(ModeloTamanhosPizza tamanho) {
    final quantidadeAntes = edicao.cardapio.saboresPizzaSelecionados.length;
    final mudou = edicao.selecionarTamanhoPizza(tamanho);
    if (!mudou) return;
    final quantidadeDepois = edicao.cardapio.saboresPizzaSelecionados.length;
    FeedbackUsuario.selecaoAlterada();
    if (quantidadeAntes > 0 && quantidadeDepois == 0) {
      _avisar('Selecione os sabores disponíveis para esse tamanho.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: _categorias.length,
      child: ListenableBuilder(
        listenable: Listenable.merge([edicao, edicao.produto, edicao.pesquisa]),
        builder: (context, _) {
          final quantidade = sabores
              ? edicao.cardapio.saboresPizzaSelecionados.length
              : edicao.produto
                  .retornarDadosPorID([opcao.id], false, '0').length;
          return PopScope(
            canPop: _permitirSair || !edicao.alterado,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _confirmarSaida();
            },
            child: Scaffold(
              appBar: AppBar(
                backgroundColor: cs.inversePrimary,
                title: Text(sabores
                    ? 'Cardápio'
                    : switch (opcao.id) {
                        6 => 'Bordas',
                        7 => 'Adicionais',
                        8 => 'Itens para retirar',
                        _ => opcao.titulo,
                      }),
                bottom: sabores
                    ? TabBar(
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        tabs: [
                          for (final categoria in _categorias)
                            Tab(text: categoria.nomeCategoria)
                        ],
                        onTap: (index) {
                          _debounce?.cancel();
                          _categoria = _categorias[index].id;
                          if (_rolagem.hasClients) _rolagem.jumpTo(0);
                          _carregarPesquisa();
                        },
                      )
                    : null,
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: BotaoAcaoPedido(
                    key: const Key('salvar_etapa_produto'),
                    rotulo: 'Salvar ($quantidade)',
                    total: edicao.total.obterReal(),
                    onPressed: _salvar,
                  ),
                ),
              ),
              body: sabores ? _listaSabores() : _listaOpcoes(),
            ),
          );
        },
      ),
    );
  }

  Widget _listaSabores() {
    final pesquisa = edicao.pesquisa;
    final selecionados = edicao.cardapio.saboresPizzaSelecionados;
    final ids = <String>{};
    final lista = [
      ...pesquisa.produtos
          .where((p) => edicao.cardapio.tamanhoPizzaDoProduto(p) != null),
      if (_busca.text.trim().isEmpty && !pesquisa.carregando)
        ...selecionados
            .where((p) => _categoria == '0' || p.categoria == _categoria),
    ].where((p) => ids.add(p.id)).toList();
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: TextField(
          controller: _busca,
          onChanged: _buscar,
          decoration: InputDecoration(
            hintText: 'Nome ou código',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
      Expanded(
          child: ListView(
        controller: _rolagem,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          ListaTamanhosPizza(
            provedor: edicao.cardapio,
            aoSelecionar: _selecionarTamanho,
            categoria: ModeloCategoria(
                id: '0',
                nomeCategoria: '',
                quantidadeProdutos: '0',
                tamanhosPizza: _tamanhosPizza),
          ),
          if (pesquisa.carregando)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()))
          else ...[
            for (final sabor in lista)
              Padding(
                key: ValueKey('sabor_edicao_${sabor.id}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                child: CardProduto(
                  estaPesquisando: false,
                  item: sabor,
                  categoria: null,
                  finalizar: false,
                  cardapioEdicao: edicao.cardapio,
                  aoSelecionarSabor: (item) {
                    final erro = edicao.selecionarSabor(item);
                    if (erro != null) {
                      _avisar(erro);
                    } else {
                      FeedbackUsuario.selecaoAlterada();
                    }
                  },
                ),
              ),
            if (lista.isEmpty && pesquisa.erro == null)
              const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Nenhum sabor encontrado.',
                      textAlign: TextAlign.center)),
          ],
          if (pesquisa.erro != null)
            Padding(
                padding: const EdgeInsets.all(16),
                child: Text(pesquisa.erro!, textAlign: TextAlign.center)),
          if (pesquisa.carregandoMais)
            const Center(child: CircularProgressIndicator())
          else if (!pesquisa.carregando &&
              (pesquisa.erro != null || pesquisa.temMais))
            TextButton.icon(
              onPressed: () =>
                  pesquisa.erroAoCarregarMais || pesquisa.erro == null
                      ? pesquisa.listarProdutosPorCategoria(_categoria,
                          carregarMais: true)
                      : _carregarPesquisa(),
              icon: Icon(
                  pesquisa.erro == null ? Icons.expand_more : Icons.refresh),
              label: Text(
                  pesquisa.erro == null ? 'Carregar mais' : 'Tentar novamente'),
            ),
        ],
      )),
    ]);
  }

  Widget _listaOpcoes() => ListView(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
                '${opcao.titulo} (${opcao.dados?.length ?? opcao.produtos?.length ?? 0})',
                style: const TextStyle(fontSize: 16)),
          ),
          if (opcao.id == 6 && edicao.pizza)
            Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: ListaBordas(
                cardapio: edicao.cardapio,
                produto: edicao.produto,
                limite: edicao.limiteBordas,
                aoSelecionarLimite: (limite) {
                  final selecionados =
                      edicao.produto.retornarDadosPorID([6], false, '0');
                  if (limite < selecionados.length) {
                    _avisar(
                        'Desmarque uma borda antes de diminuir a quantidade de sabores.');
                    return;
                  }
                  edicao.selecionarLimiteBorda(limite);
                  FeedbackUsuario.selecaoAlterada();
                },
              ),
            ),
          for (final dado in opcao.dados ?? [])
            CardOpcoesPacotes(
              key: ValueKey('editar_${opcao.id}_${dado.id}'),
              provedor: edicao.produto,
              opcoesPacote: opcao,
              item: dado,
              kit: false,
              idProduto: '0',
            ),
          for (final componente in opcao.produtos ?? [])
            ExpansionTile(
              title: Text(componente.nome),
              children: [
                for (final grupo
                    in componente.opcoesPacotes ?? <ModeloOpcoesPacotes>[])
                  for (final dado in grupo.dados ?? [])
                    CardOpcoesPacotes(
                        provedor: edicao.produto,
                        opcoesPacote: grupo,
                        item: dado,
                        kit: true,
                        idProduto: componente.id),
              ],
            ),
        ],
      );
}
