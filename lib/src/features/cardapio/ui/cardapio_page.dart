import 'package:app/src/features/cardapio/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/busca_mesas.dart';
import 'package:app/src/features/cardapio/ui/widgets/tab_custom.dart';
import 'package:app/src/widgets/custom_physics_tabview.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioPage extends StatefulWidget {
  final String? id;
  const CardapioPage({super.key, this.id});

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
                    children: categorias.map((e) => TabCustom(category: e.id)).toList(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
