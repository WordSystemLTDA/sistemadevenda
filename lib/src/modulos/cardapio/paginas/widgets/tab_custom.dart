import 'dart:async';

import 'package:app/src/essencial/widgets/campo_busca.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final ModeloCategoria categoria;
  final bool finalizar;

  const TabCustom({super.key, required this.category, required this.categoria, required this.finalizar});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final ProvedorProdutos provedor = Modular.get<ProvedorProdutos>();
  final _scrollController = ScrollController();
  final _pesquisaController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_carregarMais);
    _atualizar();
  }

  void _carregarMais() {
    if (_scrollController.hasClients && _scrollController.position.extentAfter < 240 && _pesquisaController.text.trim().isEmpty && provedor.erro == null) {
      provedor.listarProdutosPorCategoria(widget.category, carregarMais: true);
    }
  }

  Future<void> _atualizar() {
    _debounce?.cancel();
    final pesquisa = _pesquisaController.text.trim();
    if (pesquisa.isEmpty) {
      return provedor.listarProdutosPorCategoria(widget.category);
    }
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

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _pesquisaController.dispose();
    provedor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: CampoBusca(
            controller: _pesquisaController,
            hintText: 'Nome ou código',
            onChanged: _pesquisar,
            onSubmitted: (_) {
              FocusScope.of(context).unfocus();
              _atualizar();
            },
          ),
        ),
        if (widget.categoria.tamanhosPizza?.isNotEmpty ?? false) ListaTamanhosPizza(categoria: widget.categoria),
        Expanded(
          child: ListenableBuilder(
            listenable: provedor,
            builder: (context, _) => Column(
              children: [
                SizedBox(
                  height: 2,
                  child: provedor.carregando ? const LinearProgressIndicator(minHeight: 2) : null,
                ),
                if (provedor.erro != null && !provedor.erroAoCarregarMais && provedor.produtos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(provedor.erro!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
                        IconButton(tooltip: 'Tentar novamente', onPressed: _atualizar, icon: const Icon(Icons.refresh)),
                      ],
                    ),
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _atualizar,
                    child: CustomScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (provedor.produtos.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: provedor.carregando ? const CircularProgressIndicator() : _estadoLista(context),
                            ),
                          )
                        else ...[
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                            sliver: SliverList.builder(
                              itemCount: provedor.produtos.length,
                              itemBuilder: (context, index) {
                                final item = provedor.produtos[index];
                                return IgnorePointer(
                                  ignoring: provedor.carregando || (provedor.erro != null && !provedor.erroAoCarregarMais),
                                  child: CardProduto(
                                    key: ValueKey(item.id),
                                    estaPesquisando: false,
                                    item: item,
                                    categoria: widget.categoria,
                                    finalizar: widget.finalizar,
                                  ),
                                );
                              },
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Center(child: _estadoLista(context)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _estadoLista(BuildContext context) {
    if (provedor.carregandoMais) {
      return const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (provedor.erro != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(provedor.erro!, textAlign: TextAlign.center),
          TextButton.icon(
            onPressed: () {
              if (provedor.erroAoCarregarMais) {
                provedor.listarProdutosPorCategoria(widget.category, carregarMais: true);
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
    if (provedor.produtos.isEmpty) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 36, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(height: 8),
          const Text('Nenhum produto encontrado'),
        ],
      );
    }
    if (provedor.temMais) {
      return TextButton.icon(
        onPressed: provedor.carregando ? null : () => provedor.listarProdutosPorCategoria(widget.category, carregarMais: true),
        icon: const Icon(Icons.expand_more),
        label: const Text('Carregar mais'),
      );
    }
    return Text('Fim da lista', style: Theme.of(context).textTheme.bodySmall);
  }
}
