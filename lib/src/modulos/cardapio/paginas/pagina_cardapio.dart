// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:app/src/essencial/widgets/custom_physics_tabview.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/tab_custom.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:app/src/modulos/produto/paginas/pagina_sabor_bordas.dart';
import 'package:badges/badges.dart' as badges;
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

enum TipoCardapio {
  comanda,
  mesa,
  delivery,
  balcao;

  String get nome {
    switch (this) {
      case TipoCardapio.comanda:
        return 'Comanda';
      case TipoCardapio.mesa:
        return 'Mesa';
      case TipoCardapio.delivery:
        return 'Delivery';
      case TipoCardapio.balcao:
        return 'Balcão';
    }
  }

  String get nomeSimplificado {
    switch (this) {
      case TipoCardapio.comanda:
        return 'comandas';
      case TipoCardapio.mesa:
        return 'mesas';
      case TipoCardapio.delivery:
        return 'delivery';
      case TipoCardapio.balcao:
        return 'balcao';
    }
  }
}

class PaginaCardapio extends StatefulWidget {
  final TipoCardapio tipo;
  final String? id;
  final String? idComanda;
  final String? idMesa;
  final String? idCliente;
  final String? tipodeentrega;

  const PaginaCardapio({
    super.key,
    required this.tipo,
    this.id,
    this.idComanda,
    this.idMesa,
    this.idCliente,
    this.tipodeentrega,
  });

  @override
  State<PaginaCardapio> createState() => _PaginaCardapioState();
}

class _PaginaCardapioState extends State<PaginaCardapio> with TickerProviderStateMixin {
  final ProvedorCardapio provedor = Modular.get<ProvedorCardapio>();
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProdutos provedorProdutos = Modular.get<ProvedorProdutos>();

  TabController? _tabController;
  List<String> listaCategorias = [];
  int indexTabBar = 0;

  @override
  void initState() {
    super.initState();
    setarCampos();
    listarDados();
  }

  @override
  void dispose() {
    super.dispose();
    if (_tabController != null) {
      _tabController!.dispose();
    }
  }

  void listarDados() async {
    await provedor.listarCategorias().then((value) {
      _tabController = TabController(
        initialIndex: indexTabBar,
        length: value.length,
        vsync: this,
      );

      _tabController!.addListener(() {
        provedor.tamanhosPizza = null;
        provedor.saboresPizzaSelecionados = [];
        setState(() {
          indexTabBar = _tabController!.index;
        });
      });
    });

    // await provedor
    //         .listarDados(false, widget.argumentos.id, widget.argumentos.tipo, finalizar, widget.argumentos.tipodeentrega!, produtosNovos: widget.argumentos.produtosNovos)
    //         .then((value) async {
    //       if (widget.argumentos.finalizar == false) {
    //         provedor.listarProdutos(provedor.categoriaSelecionada, finalizar: finalizar);
    //       }
    //       _updateTimer();
    //     });

    await carrinhoProvedor.listarComandasPedidos();
    await provedor.listarConfigBigChef();
  }

  void setarCampos() {
    provedor.tipo = widget.tipo;
    provedor.idComanda = widget.idComanda ?? '0';
    provedor.idMesa = widget.idMesa ?? '0';
    provedor.idCliente = widget.idCliente ?? '0';
    provedor.id = widget.id ?? '0';
    provedor.tipodeentrega = widget.tipodeentrega ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: provedor,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.0),
              child: Column(
                children: [
                  // BuscarProdutos(
                  //   categoria: provedor.categorias.isEmpty ? null : provedor.categorias[indexTabBar],
                  //   idcliente: '0',
                  // ),

                  const SizedBox(height: 5),
                  Visibility(
                    visible: _tabController != null,
                    replacement: const SizedBox(
                      height: 48,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: LinearProgressIndicator(),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TabBar(
                        indicatorSize: TabBarIndicatorSize.tab,
                        controller: _tabController,
                        tabAlignment: TabAlignment.start,
                        isScrollable: true,
                        tabs: [
                          ...provedor.categorias.map((e) => Tab(
                                  child: Text(
                                e.nomeCategoria.toUpperCase(),
                                style: const TextStyle(fontSize: 16),
                              )))
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: AnimatedBuilder(
            animation: carrinhoProvedor,
            builder: (context, _) {
              return Stack(
                children: [
                  if (provedor.tamanhosPizza != null && provedor.saboresPizzaSelecionados.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: 170,
                        child: FloatingActionButton.extended(
                          heroTag: 'botao1',
                          onPressed: () async {
                            if (!context.mounted) return;

                            var item = provedor.saboresPizzaSelecionados[0];

                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) {
                                return PaginaSaborBordas(
                                  produto: item,
                                  valorVenda: provedor.calcularPrecoPizza(),
                                );
                              },
                            ));
                          },
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          label: Text('Avançar ${provedor.calcularPrecoPizza().obterReal()}'),
                        ),
                      ),
                    ),
                  ],
                  Positioned(
                    right: 25,
                    bottom: 0,
                    child: badges.Badge(
                      badgeContent: Text(carrinhoProvedor.itensCarrinho.quantidadeTotal.toStringAsFixed(0), style: const TextStyle(color: Colors.white)),
                      position: badges.BadgePosition.topEnd(end: 0),
                      child: FloatingActionButton(
                        heroTag: 'botao2',
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) {
                              return const PaginaCarrinho();
                            },
                          ));
                        },
                        shape: const CircleBorder(),
                        child: const Icon(Icons.shopping_cart),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          body: DefaultTabController(
            length: provedor.categorias.length,
            child: TabBarView(
              controller: _tabController,
              physics: const CustomTabBarViewScrollPhysics(),
              children: [
                ...provedor.categorias.map((e) {
                  listaCategorias.add(e.id);

                  return TabCustom(
                    category: e.id,
                    categoria: e,
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
