import 'dart:async';
import 'package:app/src/essencial/api/socket/monitor_atualizacao_tela.dart';
import 'package:app/src/essencial/api/socket/eventos_catalogo.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/widgets/campo_busca.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/favoritos_produtos.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final ModeloCategoria categoria;
  final bool finalizar;
  final FavoritosProdutos? favoritos;
  final VoidCallback? onPedidoVoz;
  final VoidCallback? onPararVoz;
  final bool vozOcupada;
  final bool vozGravando;
  final String? pesquisaVoz;
  final int pesquisaVozVersao;
  final bool modeloRecorrente;

  const TabCustom({
    super.key,
    required this.category,
    required this.categoria,
    required this.finalizar,
    this.favoritos,
    this.onPedidoVoz,
    this.onPararVoz,
    this.vozOcupada = false,
    this.vozGravando = false,
    this.pesquisaVoz,
    this.pesquisaVozVersao = 0,
    this.modeloRecorrente = false,
  });

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ProvedorProdutos provedor = Modular.get<ProvedorProdutos>();
  final _scrollController = ScrollController();
  final _pesquisaController = TextEditingController();
  Timer? _debounce;
  bool _somenteFavoritos = false;
  final _sincronizador = Sincronizador.instancia;
  MonitorAtualizacaoTela? _monitorCatalogo;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_carregarMais);
    _sincronizador?.revisaoCatalogo.addListener(_catalogoAtualizado);
    EventosCatalogo.produtos.addListener(_catalogoAtualizado);
    _monitorCatalogo = MonitorAtualizacaoTela(
      intervalo: const Duration(seconds: 10),
      estaAtiva: () =>
          mounted &&
          // Compatibilidade com o Flutter 3.44 usado na distribuicao.
          // ignore: deprecated_member_use
          TickerMode.getNotifier(context).value &&
          ModalRoute.of(context)?.isCurrent != false,
      atualizar: () => provedor.atualizarSilenciosamente(widget.category),
    );
    _atualizar();
    final pesquisaVoz = widget.pesquisaVoz?.trim();
    if (pesquisaVoz?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _aplicarPesquisaVoz(pesquisaVoz!);
      });
    }
  }

  @override
  void didUpdateWidget(covariant TabCustom oldWidget) {
    super.didUpdateWidget(oldWidget);
    final pesquisaVoz = widget.pesquisaVoz?.trim();
    if (pesquisaVoz?.isNotEmpty == true &&
        (oldWidget.pesquisaVozVersao != widget.pesquisaVozVersao ||
            oldWidget.pesquisaVoz != widget.pesquisaVoz)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _aplicarPesquisaVoz(pesquisaVoz!);
      });
    }
  }

  void _aplicarPesquisaVoz(String termo) {
    _debounce?.cancel();
    _somenteFavoritos = false;
    _pesquisaController.value = TextEditingValue(
        text: termo, selection: TextSelection.collapsed(offset: termo.length));
    provedor.prepararPesquisa(termo);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    unawaited(_atualizar());
    setState(() {});
  }

  void _catalogoAtualizado() {
    unawaited(_monitorCatalogo?.solicitar());
  }

  void _carregarMais() {
    if (!_somenteFavoritos &&
        _scrollController.hasClients &&
        _scrollController.position.extentAfter < 240 &&
        _pesquisaController.text.trim().isEmpty &&
        provedor.erro == null) {
      provedor.listarProdutosPorCategoria(widget.category, carregarMais: true);
    }
  }

  Future<void> _atualizar() {
    _debounce?.cancel();
    final pesquisa = _pesquisaController.text.trim();
    if (pesquisa.isEmpty && !_somenteFavoritos) {
      return provedor.listarProdutosPorCategoria(widget.category);
    }
    // A busca completa inclui favoritos alem da primeira pagina do catalogo.
    return provedor.listarProdutosPorNome(pesquisa, widget.category, '0');
  }

  void _pesquisar(String value) {
    _debounce?.cancel();
    provedor.prepararPesquisa(value);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    if (value.trim().isEmpty) {
      _atualizar();
    } else {
      _debounce = Timer(const Duration(milliseconds: 300), _atualizar);
    }
  }

  void _alternarFiltro() {
    setState(() => _somenteFavoritos = !_somenteFavoritos);
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    _atualizar();
  }

  Future<void> _alternarFavorito(String id) async {
    final favoritos = widget.favoritos;
    if (favoritos == null) return;
    final salvo = await favoritos.alternar(id);
    if (!mounted || salvo) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(favoritos.erro ?? 'Favoritos indisponíveis no momento.'),
    ));
  }

  @override
  void dispose() {
    EventosCatalogo.produtos.removeListener(_catalogoAtualizado);
    _monitorCatalogo?.dispose();
    _sincronizador?.revisaoCatalogo.removeListener(_catalogoAtualizado);
    _debounce?.cancel();
    _scrollController.dispose();
    _pesquisaController.dispose();
    provedor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge(
          [provedor, if (widget.favoritos != null) widget.favoritos!]),
      builder: (context, _) {
        final produtos = _somenteFavoritos
            ? provedor.produtos
                .where((p) => widget.favoritos?.contem(p.id) ?? false)
                .toList()
            : provedor.produtos;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Row(
                children: [
                  Expanded(
                    child: CampoBusca(
                      controller: _pesquisaController,
                      hintText: _somenteFavoritos
                          ? 'Buscar nos favoritos'
                          : 'Nome ou código',
                      onChanged: _pesquisar,
                      onSubmitted: (_) {
                        FocusScope.of(context).unfocus();
                        _atualizar();
                      },
                    ),
                  ),
                  if (widget.favoritos != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      key: const ValueKey('filtrar_favoritos'),
                      tooltip: _somenteFavoritos
                          ? 'Mostrar todos os produtos'
                          : 'Mostrar favoritos',
                      isSelected: _somenteFavoritos,
                      selectedIcon: const Icon(Icons.star_rounded),
                      icon: const Icon(Icons.star_outline_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: _somenteFavoritos
                            ? cs.secondaryContainer
                            : cs.surfaceContainerLow,
                        foregroundColor: cs.onSurfaceVariant,
                      ),
                      onPressed:
                          widget.favoritos!.disponivel ? _alternarFiltro : null,
                    ),
                  ],
                  if (widget.onPedidoVoz != null) ...[
                    const SizedBox(width: 4),
                    IconButton.filledTonal(
                      key: const ValueKey('pedido_por_voz'),
                      tooltip: widget.vozGravando
                          ? 'Parar gravação'
                          : 'Pedido por voz',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        foregroundColor: widget.vozGravando ? cs.error : null,
                      ),
                      onPressed: widget.vozGravando
                          ? widget.onPararVoz
                          : widget.vozOcupada
                              ? null
                              : widget.onPedidoVoz,
                      icon: widget.vozGravando
                          ? const Icon(Icons.stop_circle_outlined)
                          : widget.vozOcupada
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.mic_rounded),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: provedor.carregando
                  ? const LinearProgressIndicator(minHeight: 2)
                  : null,
            ),
            if (widget.favoritos?.erro != null)
              Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text(widget.favoritos!.erro!,
                          style: TextStyle(color: cs.error))),
                  IconButton(
                      tooltip: 'Recarregar favoritos',
                      onPressed: widget.favoritos!.carregar,
                      icon: const Icon(Icons.refresh)),
                ],
              ),
            if (_somenteFavoritos)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Favoritos',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant)),
                ),
              ),
            if (provedor.erro != null &&
                !provedor.erroAoCarregarMais &&
                produtos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(provedor.erro!,
                            style: TextStyle(color: cs.error))),
                    IconButton(
                        tooltip: 'Tentar novamente',
                        onPressed: _atualizar,
                        icon: const Icon(Icons.refresh)),
                  ],
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _atualizar,
                child: CustomScrollView(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    if ((widget.categoria.tamanhosPizza?.isNotEmpty ?? false) &&
                        (!_somenteFavoritos ||
                            produtos.any(
                                (p) => p.tamanhosPizza?.isNotEmpty ?? false)))
                      SliverToBoxAdapter(
                          child:
                              ListaTamanhosPizza(categoria: widget.categoria)),
                    if (produtos.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: provedor.carregando
                              ? const CircularProgressIndicator()
                              : _estadoLista(context, vazio: true),
                        ),
                      )
                    else ...[
                      SliverLayoutBuilder(builder: (context, constraints) {
                        final colunas = constraints.crossAxisExtent >= 720 &&
                                MediaQuery.textScalerOf(context).scale(16) <= 24
                            ? 2
                            : 1;
                        return SliverPadding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                          sliver: SliverList.builder(
                            itemCount: (produtos.length / colunas).ceil(),
                            itemBuilder: (context, index) {
                              Widget produto(int posicao) {
                                final item = produtos[posicao];
                                return IgnorePointer(
                                  ignoring: provedor.carregando ||
                                      (provedor.erro != null &&
                                          !provedor.erroAoCarregarMais),
                                  child: CardProduto(
                                    key: ValueKey(item.id),
                                    estaPesquisando: false,
                                    item: item,
                                    categoria: widget.categoria,
                                    finalizar: widget.finalizar,
                                    modeloRecorrente: widget.modeloRecorrente,
                                    favorito:
                                        widget.favoritos?.contem(item.id) ??
                                            false,
                                    aoAlternarFavorito:
                                        widget.favoritos?.disponivel == true
                                            ? () => _alternarFavorito(item.id)
                                            : null,
                                  ),
                                );
                              }

                              if (colunas == 1) return produto(index);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: produto(index * 2)),
                                  Expanded(
                                      child: index * 2 + 1 < produtos.length
                                          ? produto(index * 2 + 1)
                                          : const SizedBox()),
                                ],
                              );
                            },
                          ),
                        );
                      }),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Center(child: _estadoLista(context)),
                        ),
                      ),
                    ],
                    SliverToBoxAdapter(
                        child: SizedBox(
                            height: MediaQuery.paddingOf(context).bottom +
                                MediaQuery.textScalerOf(context).scale(72))),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _estadoLista(BuildContext context, {bool vazio = false}) {
    if (provedor.carregandoMais) {
      return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (provedor.erro != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(provedor.erro!, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: () {
              if (provedor.erroAoCarregarMais && !_somenteFavoritos) {
                provedor.listarProdutosPorCategoria(widget.category,
                    carregarMais: true);
              } else {
                _atualizar();
              }
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar novamente'),
          ),
        ],
      );
    }
    if (vazio) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                _somenteFavoritos
                    ? Icons.star_outline_rounded
                    : Icons.search_off_rounded,
                size: 36,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
                _somenteFavoritos
                    ? 'Nenhum favorito nesta seleção'
                    : 'Nenhum produto encontrado',
                textAlign: TextAlign.center),
          ],
        ),
      );
    }
    if (provedor.temMais && !_somenteFavoritos) {
      return TextButton.icon(
        onPressed: provedor.carregando
            ? null
            : () => provedor.listarProdutosPorCategoria(widget.category,
                carregarMais: true),
        icon: const Icon(Icons.expand_more),
        label: const Text('Carregar mais'),
      );
    }
    return Text('Fim da lista', style: Theme.of(context).textTheme.bodySmall);
  }
}
