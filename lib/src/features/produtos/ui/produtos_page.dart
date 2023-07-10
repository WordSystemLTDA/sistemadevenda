import 'package:app/src/features/produtos/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/produtos/interactor/states/categorias_state.dart';
import 'package:app/src/features/produtos/ui/widgets/tab_custom.dart';
import 'package:app/src/widgets/custom_physics_tabview.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ProdutosPage extends StatefulWidget {
  final String idMesa;
  const ProdutosPage({super.key, required this.idMesa});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> with TickerProviderStateMixin {
  final CategoriasCubit _categoriasCubit = Modular.get<CategoriasCubit>();
  late TabController _tabController;
  final _searchController = SearchController();

  @override
  void initState() {
    _categoriasCubit.getCategorias();
    // _searchController.text = "Mesa ${widget.idMesa}";
    super.initState();
  }

  final leading = InkWell(
    onTap: () {
      Modular.to.pop();
    },
    borderRadius: BorderRadius.circular(50),
    child: const Padding(
      padding: EdgeInsets.all(8.0),
      child: Icon(Icons.arrow_back_outlined),
    ),
  );

  final trailing = [
    IconButton(
      icon: const Icon(Icons.keyboard_voice),
      onPressed: () {
        print('Use voice command');
      },
    ),
  ];

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
                  SearchAnchor(
                    searchController: _searchController,
                    builder: (BuildContext context, SearchController controller) {
                      return SearchBar(
                        leading: leading,
                        trailing: trailing,
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
                        onTap: () {
                          _searchController.openView();
                        },
                      );
                    },
                    suggestionsBuilder: (BuildContext context, SearchController controller) {
                      final keyword = controller.value.text;
                      return List.generate(5, (index) => 'Item $index').where((element) => element.toLowerCase().startsWith(keyword.toLowerCase())).map(
                            (item) => GestureDetector(
                              onTap: () {
                                setState(() {
                                  controller.closeView(item);
                                });
                              },
                              child: Card(
                                color: Colors.amber,
                                child: Center(child: Text(item)),
                              ),
                            ),
                          );
                    },
                    viewBuilder: (Iterable<Widget> suggestions) {
                      return GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                        ),
                        itemCount: suggestions.length,
                        itemBuilder: (BuildContext context, int index) {
                          return suggestions.elementAt(index);
                        },
                      );
                    },
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
