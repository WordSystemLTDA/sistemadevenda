import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/busca_mesas.dart';
import 'package:app/src/features/cardapio/ui/widgets/tab_custom.dart';
import 'package:app/src/shared/widgets/custom_physics_tabview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioPage extends StatefulWidget {
  final String? idComanda;
  final String tipo;
  final String idMesa;
  const CardapioPage({super.key, this.idComanda, required this.tipo, required this.idMesa});

  @override
  State<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends State<CardapioPage> with TickerProviderStateMixin {
  final ItensComandaState _stateItensComanda = ItensComandaState();
  final CategortiaState _stateCategorias = CategortiaState();

  late TabController _tabController;

  List<String> listaCategorias = [];
  int indexTabBar = 0;

  void listarComandasPedidos() async {
    await _stateItensComanda.listarComandasPedidos(widget.idComanda!, widget.idMesa);
  }

  void listarCategorias() async {
    _stateCategorias.listarCategorias();
  }

  @override
  void initState() {
    super.initState();

    listarCategorias();
    listarComandasPedidos();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: categoriaState,
      builder: (context, value, child) {
        _tabController = TabController(
          initialIndex: indexTabBar,
          length: value.length,
          vsync: this,
        );

        _tabController.addListener(() => indexTabBar = _tabController.index);

        return Scaffold(
          floatingActionButton: ValueListenableBuilder(
            valueListenable: itensComandaState,
            builder: (context, value, child) => FloatingActionButton(
              onPressed: () {
                Modular.to.pushNamed('/cardapio/carrinho/${widget.idComanda!}/${widget.idMesa}');
              },
              shape: const CircleBorder(),
              child: Badge(
                largeSize: 25,
                textStyle: const TextStyle(fontSize: 16),
                padding: value.quantidadeTotal < 10 ? const EdgeInsets.symmetric(vertical: 0, horizontal: 9) : const EdgeInsets.all(5),
                offset: const Offset(20, -20),
                label: Text(value.quantidadeTotal.toStringAsFixed(0)),
                isLabelVisible: true,
                child: const Icon(
                  Icons.shopping_cart,
                  size: 30,
                ),
              ),
            ),
          ),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50.0),
              child: Column(
                children: [
                  BuscaMesas(
                    idComanda: widget.idComanda!,
                    tipo: widget.tipo,
                    idMesa: widget.idMesa,
                    // categoria: listaCategorias[indexTabBar] ?? '',
                    // categoria: '1',
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TabBar(
                      indicatorSize: TabBarIndicatorSize.tab,
                      controller: _tabController,
                      tabAlignment: TabAlignment.start,
                      isScrollable: true,
                      tabs: [
                        ...value
                            .map((e) => Tab(
                                    child: Text(
                                  e.nomeCategoria.toUpperCase(),
                                  style: const TextStyle(fontSize: 16),
                                )))
                            .toList()
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: DefaultTabController(
            length: value.length,
            child: TabBarView(
              controller: _tabController,
              physics: const CustomTabBarViewScrollPhysics(),
              children: [
                ...value.map((e) {
                  listaCategorias.add(e.id);

                  return TabCustom(
                    category: e.id,
                    idMesa: widget.idMesa,
                    idComanda: widget.idComanda == '0' ? '' : widget.idComanda,
                    tipo: widget.tipo,
                  );
                }).toList()
              ],
            ),
          ),
        );
      },
    );
  }
}
