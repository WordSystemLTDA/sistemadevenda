// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'package:app/src/essencial/widgets/custom_physics_tabview.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/buscar_produtos.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/tab_custom.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
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
  final String? idComanda;
  final TipoCardapio tipo;
  final String? idMesa;
  final String? idCliente;
  final String? idComandaPedido;

  const PaginaCardapio({
    super.key,
    this.idComanda,
    required this.tipo,
    this.idMesa,
    this.idCliente,
    this.idComandaPedido,
  });

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

    listarDados();
  }

  void listarDados() async {
    await provedorCardapio.listarCategorias();
    await carrinhoProvedor.listarComandasPedidos(widget.idComandaPedido!);
    await provedorCardapio.listarConfigBigChef();
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

        _tabController.addListener(() {
          provedorCardapio.tamanhosPizza = null;
          provedorCardapio.saboresPizzaSelecionados = [];
          setState(() {
            indexTabBar = _tabController.index;
          });
        });

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(50.0),
              child: Column(
                children: [
                  BuscarProdutos(
                    idComanda: widget.idComanda!,
                    idComandaPedido: widget.idComandaPedido!,
                    tipo: widget.tipo,
                    idMesa: widget.idMesa!,
                    categoria: provedorCardapio.categorias.isEmpty ? null : provedorCardapio.categorias[indexTabBar],
                    idcliente: '0',
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
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButton: AnimatedBuilder(
            animation: carrinhoProvedor,
            builder: (context, _) {
              return Stack(
                children: [
                  if (provedorCardapio.tamanhosPizza != null && provedorCardapio.saboresPizzaSelecionados.isNotEmpty) ...[
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SizedBox(
                        width: 170,
                        child: FloatingActionButton.extended(
                          heroTag: 'botao1',
                          onPressed: () async {
                            if (!context.mounted) return;

                            var item = provedorCardapio.saboresPizzaSelecionados[0];

                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) {
                                return PaginaSaborBordas(
                                  idComanda: widget.idComanda!,
                                  idComandaPedido: widget.idComandaPedido!,
                                  idMesa: widget.idMesa!,
                                  tipo: widget.tipo,
                                  produto: item,
                                  valorVenda: provedorCardapio.calcularPrecoPizza(),
                                );
                              },
                            ));
                          },
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          label: Text('Avançar ${provedorCardapio.calcularPrecoPizza().obterReal()}'),
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
                              return PaginaCarrinho(
                                idComanda: widget.idComanda!,
                                idMesa: widget.idMesa!,
                                idCliente: widget.idCliente!,
                                idComandaPedido: widget.idComandaPedido!,
                                tipo: widget.tipo,
                              );
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
            length: provedorCardapio.categorias.length,
            child: TabBarView(
              controller: _tabController,
              physics: const CustomTabBarViewScrollPhysics(),
              children: [
                ...provedorCardapio.categorias.map((e) {
                  listaCategorias.add(e.id);

                  return TabCustom(
                    category: e.id,
                    idMesa: widget.idMesa!,
                    categoria: e,
                    idComandaPedido: widget.idComandaPedido!,
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
