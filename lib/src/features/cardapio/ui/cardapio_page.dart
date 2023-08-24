import 'package:app/src/features/cardapio/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/busca_mesas.dart';
import 'package:app/src/features/cardapio/ui/widgets/tab_custom.dart';
import 'package:app/src/shared/widgets/custom_physics_tabview.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioPage extends StatefulWidget {
  final String? idLugar;
  final String tipo;
  const CardapioPage({super.key, this.idLugar, required this.tipo});

  @override
  State<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends State<CardapioPage> with TickerProviderStateMixin {
  final CategoriasCubit _categoriasCubit = Modular.get<CategoriasCubit>();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _categoriasCubit.getCategorias();
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
                  //print('called on tap');
                },
                child: SizedBox(
                  height: kToolbarHeight,
                  width: double.infinity,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: itemWidth,
                        padding: const EdgeInsets.only(left: 30),
                        child: const Row(
                          children: [
                            Icon(Icons.balance, size: 18),
                            SizedBox(width: 8),
                            Text('4', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.left),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: const Text('Ver itens', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      ),
                      Container(
                        width: itemWidth,
                        padding: const EdgeInsets.only(right: 30),
                        child: const Text('R\$ 5,00',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
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
                              idLugar: widget.idLugar == '0' ? '' : widget.idLugar,
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
