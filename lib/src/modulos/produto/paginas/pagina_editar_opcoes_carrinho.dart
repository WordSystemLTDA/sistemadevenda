import 'dart:async';

import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/observacao_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_bordas.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/uteis/montagem_cardapio.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/paginas/widgets/etapa_montagem_cardapio.dart';
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
  ModeloDadosOpcoesPacotes? _itemTrocaCardapio;
  ModeloDadosOpcoesPacotes? _destinoTrocaCardapio;
  String? _tipoDestinoTrocaCardapio;
  int _quantidadeTrocaCardapio = 1;
  String get _valorEmbalagemSeparada =>
      (double.tryParse(edicao.cardapio.configBigchef?.valorembalagemseparada
                      .replaceAll(',', '.') ??
                  '') ??
              0)
          .toStringAsFixed(2);
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

  bool _idCardapioValido(String? id) {
    final texto = id?.trim() ?? '';
    return texto.isNotEmpty && texto != '0' && texto.toLowerCase() != 'null';
  }

  bool _grupoMontagemCardapio(ModeloOpcoesPacotes grupo) {
    if (grupoObservacaoProduto(grupo)) return false;
    if (grupo.tipo == 8) return true;
    return (grupo.dados ?? const <ModeloDadosOpcoesPacotes>[]).any(
      (dado) =>
          dado.montagemCardapio != null ||
          _idCardapioValido(dado.idCategoriaCardapio),
    );
  }

  ModeloOpcoesPacotes? get _grupoMontagemSelecionado =>
      edicao.produto.opcoesPacotesListaFinal
          .where(_grupoMontagemCardapio)
          .firstOrNull;

  List<ModeloDadosOpcoesPacotes> get _ingredientesMontagemCardapio =>
      _grupoMontagemSelecionado?.dados ?? const <ModeloDadosOpcoesPacotes>[];

  List<ModeloDadosOpcoesPacotes> _adicionaisDisponiveisTrocaCardapio() {
    return edicao.opcoes
        .where((grupo) => grupo.id == 7 || grupo.tipo == 3)
        .expand((grupo) => grupo.dados ?? const <ModeloDadosOpcoesPacotes>[])
        .map((dado) => ModeloDadosOpcoesPacotes.fromMap(dado.toMap()))
        .toList();
  }

  void _alterarIngredienteCardapio(
    ModeloDadosOpcoesPacotes item,
    AcaoIngredienteCardapio acao,
  ) {
    final dados = _grupoMontagemSelecionado?.dados;
    if (dados == null) return;
    final index = dados.indexWhere((dado) => dado.id == item.id);
    if (index < 0) return;
    final atual = dados[index];
    if (!atual.permiteMontagemCardapio(acao)) {
      _avisar(
          'A opção ${acao.rotulo} não está liberada para este ingrediente.');
      return;
    }
    final montagemAtual = atual.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: atual.nome);
    final montagem = montagemAtual.copyWith(
      acao: acao,
      limparDestino: acao != AcaoIngredienteCardapio.trocar,
      separado:
          acao == AcaoIngredienteCardapio.sem ? false : montagemAtual.separado,
      valorEmbalagemSeparada: acao == AcaoIngredienteCardapio.sem
          ? '0.00'
          : montagemAtual.valorEmbalagemSeparada,
    );

    setState(() {
      dados[index] = MontagemCardapio.aplicar(atual, montagem);
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
    });
    edicao.produto.calcularValorVenda(false, '0');
    FeedbackUsuario.selecaoAlterada();
  }

  void _separarIngredienteCardapio(
    ModeloDadosOpcoesPacotes item,
    bool separado,
  ) {
    final dados = _grupoMontagemSelecionado?.dados;
    if (dados == null) return;
    final index = dados.indexWhere((dado) => dado.id == item.id);
    if (index < 0) return;
    final atual = dados[index];
    final montagemAtual = atual.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: atual.nome);
    if (montagemAtual.acao == AcaoIngredienteCardapio.sem) return;
    final cobrarEmbalagem = separado && edicao.produtoVinculadoCardapio;

    setState(() {
      dados[index] = MontagemCardapio.aplicar(
        atual,
        montagemAtual.copyWith(
          separado: separado,
          valorEmbalagemSeparada:
              cobrarEmbalagem ? _valorEmbalagemSeparada : '0.00',
        ),
      );
    });
    edicao.produto.calcularValorVenda(false, '0');
    FeedbackUsuario.selecaoAlterada();
  }

  void _iniciarTrocaCardapio(ModeloDadosOpcoesPacotes item) {
    if (!item.permiteMontagemCardapio(AcaoIngredienteCardapio.trocar)) {
      return;
    }
    setState(() {
      _itemTrocaCardapio = item;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = item.montagemCardapio?.quantidadeTroca ?? 1;
      _busca.clear();
    });
  }

  void _selecionarDestinoTrocaCardapio(
    ModeloDadosOpcoesPacotes item,
    String tipo,
  ) {
    setState(() {
      _destinoTrocaCardapio = item;
      _tipoDestinoTrocaCardapio = tipo;
    });
  }

  void _confirmarTrocaCardapio() {
    final origem = _itemTrocaCardapio;
    final destino = _destinoTrocaCardapio;
    final tipo = _tipoDestinoTrocaCardapio;
    final dados = _grupoMontagemSelecionado?.dados;
    if (origem == null || destino == null || tipo == null || dados == null) {
      return;
    }
    final erro =
        MontagemCardapio.validarTroca(dados, origem.id, destino.id, tipo);
    if (erro != null) {
      _avisar(erro);
      return;
    }

    final index = dados.indexWhere((dado) => dado.id == origem.id);
    if (index < 0) return;
    final atual = dados[index];
    if (!atual.permiteMontagemCardapio(AcaoIngredienteCardapio.trocar)) {
      return;
    }
    final montagemAtual = atual.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: atual.nome);
    final nomeDestino = destino.montagemCardapio?.nomeOriginal ?? destino.nome;

    setState(() {
      dados[index] = MontagemCardapio.aplicar(
        atual,
        montagemAtual.copyWith(
          acao: AcaoIngredienteCardapio.trocar,
          destinoId: destino.id,
          destinoNome: nomeDestino,
          destinoTipo: tipo,
          quantidadeTroca: _quantidadeTrocaCardapio,
        ),
      );
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
      _busca.clear();
    });
    edicao.produto.calcularValorVenda(false, '0');
    FeedbackUsuario.selecaoAlterada();
  }

  void _restaurarMontagemCardapio() {
    final grupo = _grupoMontagemSelecionado;
    if (grupo == null) return;
    setState(() {
      grupo.dados = MontagemCardapio.iniciar(grupo.dados ?? []);
      _itemTrocaCardapio = null;
      _destinoTrocaCardapio = null;
      _tipoDestinoTrocaCardapio = null;
      _quantidadeTrocaCardapio = 1;
      _busca.clear();
    });
    edicao.produto.calcularValorVenda(false, '0');
    FeedbackUsuario.selecaoAlterada();
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
              : _grupoMontagemCardapio(opcao)
                  ? _ingredientesMontagemCardapio
                      .where((item) =>
                          item.montagemCardapio?.acao !=
                              AcaoIngredienteCardapio.normal ||
                          item.montagemCardapio?.separado == true)
                      .length
                  : edicao.produto
                      .retornarDadosPorID([opcao.id], false, '0').length;
          final trocaMontagem = !sabores &&
              _grupoMontagemCardapio(opcao) &&
              _itemTrocaCardapio != null;
          return PopScope(
            canPop: _permitirSair || !edicao.alterado,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _confirmarSaida();
            },
            child: Scaffold(
              extendBody: true,
              appBar: AppBar(
                backgroundColor: cs.inversePrimary,
                title: Text(sabores
                    ? 'Cardápio'
                    : switch (opcao.id) {
                        _ when _grupoMontagemCardapio(opcao) => 'Montagem',
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
                    rotulo: trocaMontagem
                        ? 'Confirmar troca'
                        : 'Salvar ($quantidade)',
                    total: edicao.total.obterReal(),
                    habilitado: !trocaMontagem || _destinoTrocaCardapio != null,
                    onPressed:
                        trocaMontagem ? _confirmarTrocaCardapio : _salvar,
                  ),
                ),
              ),
              body: sabores
                  ? _listaSabores()
                  : _grupoMontagemCardapio(opcao)
                      ? _listaMontagem()
                      : _listaOpcoes(),
            ),
          );
        },
      ),
    );
  }

  Widget _listaMontagem() {
    final itemTroca = _itemTrocaCardapio;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        14,
        12,
        14,
        MediaQuery.paddingOf(context).bottom +
            MediaQuery.textScalerOf(context).scale(88),
      ),
      child: itemTroca == null
          ? EtapaMontagemCardapio(
              nomeProduto: edicao.original.nome,
              valor: edicao.original.valorVenda,
              ingredientes: _ingredientesMontagemCardapio,
              pesquisaController: _busca,
              aoAlterar: _alterarIngredienteCardapio,
              aoSeparar: _separarIngredienteCardapio,
              aoTrocar: _iniciarTrocaCardapio,
              aoRestaurar: _restaurarMontagemCardapio,
              aoVoltar: () => Navigator.pop(context, false),
              preferenciasTodosDias: edicao.modeloRecorrente,
            )
          : EtapaTrocaCardapio(
              item: itemTroca,
              ingredientes: _ingredientesMontagemCardapio,
              adicionais: _adicionaisDisponiveisTrocaCardapio(),
              destinoSelecionado: _destinoTrocaCardapio,
              tipoSelecionado: _tipoDestinoTrocaCardapio,
              quantidade: _quantidadeTrocaCardapio,
              pesquisaController: _busca,
              aoVoltar: () => setState(() {
                _itemTrocaCardapio = null;
                _destinoTrocaCardapio = null;
                _tipoDestinoTrocaCardapio = null;
                _quantidadeTrocaCardapio = 1;
                _busca.clear();
              }),
              aoSelecionar: _selecionarDestinoTrocaCardapio,
              aoAlterarQuantidade: (quantidade) =>
                  setState(() => _quantidadeTrocaCardapio = quantidade),
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.paddingOf(context).bottom +
              MediaQuery.textScalerOf(context).scale(88),
        ),
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
        padding: EdgeInsets.fromLTRB(
          14,
          12,
          14,
          MediaQuery.paddingOf(context).bottom +
              MediaQuery.textScalerOf(context).scale(88),
        ),
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
          if (opcao.id == 6 && edicao.pizza)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ControleMeiaBorda(produto: edicao.produto),
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
