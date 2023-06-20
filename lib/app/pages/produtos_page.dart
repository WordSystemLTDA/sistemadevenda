import 'package:app/app/widgets/custom_physics_tabview.dart';
import 'package:app/app/widgets/tab_custom.dart';
import 'package:app/app/data/blocs/categorias/categorias_bloc.dart';
import 'package:app/app/data/blocs/categorias/categorias_event.dart';
import 'package:app/app/data/blocs/categorias/categorias_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ProdutosPage extends StatefulWidget {
  final String idMesa;
  const ProdutosPage({super.key, required this.idMesa});

  @override
  State<ProdutosPage> createState() => _ProdutosPageState();
}

class _ProdutosPageState extends State<ProdutosPage> with TickerProviderStateMixin {
  late final CategoriasBloc _categoriasBloc;
  late TabController _tabController;
  final _searchController = TextEditingController();

  @override
  void initState() {
    _categoriasBloc = CategoriasBloc();
    _categoriasBloc.add(GetCategorias());
    _searchController.text = "Mesa ${widget.idMesa}";
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // timeDilation = 0.1;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10.0),
          child: Column(
            children: [
              SearchBar(
                controller: _searchController,
                elevation: const MaterialStatePropertyAll(0),
                padding: const MaterialStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 20),
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
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
      body: BlocBuilder<CategoriasBloc, CategoriasState>(
        bloc: _categoriasBloc,
        builder: (context, state) {
          if (state is CategoriaLoadingState) {
            return const LinearProgressIndicator();
          } else if (state is CategoriaLoadedState) {
            final categorias = state.categorias;

            _tabController = TabController(
              initialIndex: 0,
              length: categorias.length,
              vsync: this,
            );

            return DefaultTabController(
              length: categorias.length,
              child: Scaffold(
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  bottom: PreferredSize(
                    preferredSize: const Size.fromHeight(0.0),
                    child: Column(
                      children: [
                        const SizedBox(height: 7),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            tabs: categorias.map((e) => Tab(child: Text(e.nomeCategoria.toUpperCase()))).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                body: TabBarView(
                  controller: _tabController,
                  physics: const CustomTabBarViewScrollPhysics(),
                  children: categorias.map((e) => TabCustom(category: e.id)).toList(),
                ),
              ),
            );
          } else {
            return const Text("Error");
          }
        },
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _categoriasBloc.close();
    super.dispose();
  }
}
