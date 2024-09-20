import 'package:app/src/essencial/widgets/custom_physics_tabview.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/busca_mesas.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/tab_custom.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCardapio extends StatefulWidget {
  final String? idComanda;
  final String tipo;
  final String idMesa;
  const PaginaCardapio({super.key, this.idComanda, required this.tipo, required this.idMesa});

  @override
  State<PaginaCardapio> createState() => _PaginaCardapioState();
}

class _PaginaCardapioState extends State<PaginaCardapio> with TickerProviderStateMixin {
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();

  late TabController _tabController;

  List<String> listaCategorias = [];
  int indexTabBar = 0;

  @override
  void initState() {
    super.initState();

    listarCategorias();
    listarComandasPedidos();
  }

  void listarComandasPedidos() async {
    await carrinhoProvedor.listarComandasPedidos(widget.idComanda!, widget.idMesa);
  }

  void listarCategorias() async {
    provedorCardapio.listarCategorias();
  }

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provedorCardapio,
      builder: (context, _) {
        _tabController = TabController(
          initialIndex: indexTabBar,
          length: provedorCardapio.categorias.length,
          vsync: this,
        );

        _tabController.addListener(() => indexTabBar = _tabController.index);

        return Scaffold(
          floatingActionButton: AnimatedBuilder(
            animation: carrinhoProvedor,
            builder: (context, _) {
              return FloatingActionButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) {
                      return PaginaCarrinho(idComanda: widget.idComanda!, idMesa: widget.idMesa);
                    },
                  ));
                },
                shape: const CircleBorder(),
                child: Badge(
                  largeSize: 25,
                  textStyle: const TextStyle(fontSize: 16),
                  padding: carrinhoProvedor.itensCarrinho.quantidadeTotal < 10 ? const EdgeInsets.symmetric(vertical: 0, horizontal: 9) : const EdgeInsets.all(5),
                  offset: const Offset(20, -20),
                  label: Text(carrinhoProvedor.itensCarrinho.quantidadeTotal.toStringAsFixed(0)),
                  isLabelVisible: true,
                  child: const Icon(
                    Icons.shopping_cart,
                    size: 30,
                  ),
                ),
              );
            },
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
                        ...provedorCardapio.categorias.map((e) => Tab(
                                child: Text(
                              e.nomeCategoria.toUpperCase(),
                              style: const TextStyle(fontSize: 16),
                            )))
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          body: DefaultTabController(
            length: provedorCardapio.categorias.length,
            child: TabBarView(
              controller: _tabController,
              physics: const CustomTabBarViewScrollPhysics(),
              children: [
                ...provedorCardapio.categorias.map((e) {
                  listaCategorias.add(e.id);

                  return TabCustom(
                    category: e.id,
                    idMesa: widget.idMesa,
                    idComanda: widget.idComanda == '0' ? '' : widget.idComanda,
                    tipo: widget.tipo,
                  );
                })
              ],
            ),
          ),
        );
      },
    );
  }
}
