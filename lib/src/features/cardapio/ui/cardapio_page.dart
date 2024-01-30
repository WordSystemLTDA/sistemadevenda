import 'package:app/src/features/cardapio/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
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
  late TabController _tabController;

  late List<dynamic> listaComandosPedidos;
  int quantidadeTotal = 0;
  double precoTotal = 0;

  void listarComandasPedidos() async {
    listaComandosPedidos = await _categoriasCubit.listarComandasPedidos(widget.idComanda!);
    listaComandosPedidos.map((e) {
      quantidadeTotal += int.parse(double.parse(e['quantidade']).toStringAsFixed(0));
      precoTotal += double.parse(e['valor']) * num.parse(e['quantidade']);
    }).toList();
    setState(() {});
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
    // _categoriasCubit.close();
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
          initialIndex: 0,
          length: categorias.length,
          vsync: this,
        );

        return Scaffold(
          bottomNavigationBar: Visibility(
            visible: true,
            child: Material(
              color: const Color.fromARGB(255, 61, 61, 61),
              child: InkWell(
                onTap: () {
                  // Modular.to.pushNamed('/cardapio/balcao/0');
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ItensComandaPage(listaComandosPedidos: listaComandosPedidos),
                    ),
                  );
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
                                // listaComandosPedidos.length.toString(),
                                quantidadeTotal.toString(),
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
                        child: Text('R\$ ${precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
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
          appBar: AppBar(
            automaticallyImplyLeading: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50.0),
              child: Column(
                children: [
                  const BuscaMesas(),
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
                    children: categorias
                        .map((e) => TabCustom(
                              category: e.id,
                              idComanda: widget.idComanda == '0' ? '' : widget.idComanda,
                              tipo: widget.tipo,
                            ))
                        .toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
