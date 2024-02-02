import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';
import 'package:app/src/features/cardapio/ui/itens_comanda_page.dart';
import 'package:app/src/features/cardapio/ui/widgets/tab_custom.dart';
import 'package:app/src/shared/widgets/custom_physics_tabview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioPage extends StatefulWidget {
  final String? idComanda;
  final String tipo;
  const CardapioPage({super.key, this.idComanda, required this.tipo});

  @override
  State<CardapioPage> createState() => _CardapioPageState();
}

class _CardapioPageState extends State<CardapioPage> with TickerProviderStateMixin {
  final ItensComandaState _stateItensComanda = ItensComandaState();
  final CategortiaState _stateCategorias = CategortiaState();
  late final ProdutoState _stateProdutos;

  late TabController _tabController;

  List<String> listaCategorias = [];
  int indexTabBar = 0;

  void listarComandasPedidos() async {
    await _stateItensComanda.listarComandasPedidos(widget.idComanda!);
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
    var size = MediaQuery.of(context).size;
    final double itemWidth = size.width / 3;

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
                      onChanged: (value) => _stateProdutos.listarProdutos(listaCategorias[indexTabBar]),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TabBar(
                      controller: _tabController,
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
