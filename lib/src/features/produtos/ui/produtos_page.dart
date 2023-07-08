import 'package:app/src/features/produtos/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/produtos/interactor/states/categorias_state.dart';
import 'package:app/src/features/produtos/ui/widgets/tab_custom.dart';
import 'package:app/src/widgets/custom_physics_tabview.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProdutosPage extends StatefulWidget {
  const ProdutosPage({super.key});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> with TickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    final cubit = context.read<CategoriasCubit>();
    cubit.getCategorias();

    super.initState();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final idMesa = ModalRoute.of(context)!.settings.arguments;

    _searchController.text = "Mesa $idMesa";

    final cubit = context.watch<CategoriasCubit>();
    final state = cubit.state;
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
              SearchBar(
                controller: _searchController,
                elevation: const MaterialStatePropertyAll(0),
                padding: const MaterialStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 15),
                ),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 20,
                ),
                shape: const MaterialStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(
                      Radius.circular(5),
                    ),
                  ),
                ),
                trailing: const [Icon(Icons.mic)],
                leading: InkWell(
                  onTap: () {
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(50),
                  child: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.arrow_back_outlined),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              if (state is CategoriaLoadedState)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: categorias.map((e) => Tab(child: Text(e.nomeCategoria.toUpperCase()))).toList(),
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
                children: categorias.map((e) => TabCustom(key: Key(e.id), category: e.id)).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
