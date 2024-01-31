import 'package:app/src/features/cardapio/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/ui/itens_comanda_page.dart';
import 'package:app/src/features/cardapio/ui/widgets/busca_mesas.dart';
import 'package:app/src/features/cardapio/ui/widgets/tab_custom.dart';
import 'package:app/src/shared/widgets/custom_physics_tabview.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioPage extends StatefulWidget {
  final String? idComanda;
  final String tipo;
  const CardapioPage({super.key, this.idComanda, required this.tipo});

  @override
  State<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends State<CardapioPage> with TickerProviderStateMixin {
  final CategoriasCubit _categoriasCubit = Modular.get<CategoriasCubit>();

  final ProdutosCubit _produtosCubit = Modular.get<ProdutosCubit>();

  late TabController _tabController;

  final ItensComandaState stateItensComanda = ItensComandaState();

  List<String> listaCategorias = [];
  int indexTabBar = 0;

  void listarComandasPedidos() async {
    await stateItensComanda.listarComandasPedidos(widget.idComanda!);
  }

  @override
  void initState() {
    super.initState();
    _categoriasCubit.getCategorias();

    listarComandasPedidos();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;
    final double itemWidth = size.width / 3;

    return BlocBuilder<CategoriasCubit, CategoriasState>(
      bloc: _categoriasCubit,
      builder: (context, state) {
        final categorias = state.categorias;

        _tabController = TabController(
          initialIndex: indexTabBar,
          length: categorias.length,
          vsync: this,
        );

        _tabController.addListener(() => indexTabBar = _tabController.index);

        return Scaffold(
          bottomNavigationBar: ValueListenableBuilder(
            valueListenable: itensComandaState,
            builder: (context, value, child) => Visibility(
              visible: true,
              child: Material(
                color: const Color.fromARGB(255, 61, 61, 61),
                child: InkWell(
                  onTap: () {
                    Modular.to.push(
                      MaterialPageRoute(builder: (context) => ItensComandaPage(idComanda: widget.idComanda!)),
                    );
                    // Navigator.push(
                    //   context,
                    //   MaterialPageRoute(
                    //     builder: (context) => ItensComandaPage(idComanda: widget.idComanda!),
                    //   ),
                    // );
                  },
                  child: SizedBox(
                    height: kToolbarHeight,
                    width: double.infinity,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 30),
                            child: Row(
                              children: [
                                const Icon(Icons.balance, size: 18, color: Colors.white),
                                const SizedBox(width: 8),
                                Text(
                                  value.quantidadeTotal.toStringAsFixed(0),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                                  textAlign: TextAlign.left,
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          child: const Text(
                            'Ver itens',
                            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Container(
                          width: itemWidth,
                          padding: const EdgeInsets.only(right: 30),
                          child: Text('R\$ ${value.precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.right),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50.0),
              child: Column(
                children: [
                  // BuscaMesas(
                  //   category: listaCategorias[indexTabBar],
                  //   // category: '0',
                  // ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Pesquisar...',
                        prefixIcon: IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back_outlined),
                        ),
                      ),
                      onChanged: (value) => _produtosCubit.getProdutos(listaCategorias[indexTabBar]),
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (state is CategoriaLoadedState)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        controller: _tabController,
                        isScrollable: true,
                        tabs: categorias
                            .map((e) => Tab(
                                    child: Text(
                                  e.nomeCategoria.toUpperCase(),
                                  style: const TextStyle(fontSize: 16),
                                )))
                            .toList(),
                      ),
                    ),
                  if (state is! CategoriaLoadedState) const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          body: Stack(
            children: [
              if (state is CategoriaLoadingState) const SizedBox(height: 1, child: LinearProgressIndicator()),
              if (state is CategoriaLoadedState)
                DefaultTabController(
                  length: categorias.length,
                  child: TabBarView(
                    controller: _tabController,
                    physics: const CustomTabBarViewScrollPhysics(),
                    children: categorias.map((e) {
                      listaCategorias.add(e.id);

                      return TabCustom(
                        category: e.id,
                        idComanda: widget.idComanda == '0' ? '' : widget.idComanda,
                        tipo: widget.tipo,
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
