// ignore_for_file: public_member_api_docs, sort_constructors_first
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
  bool finalizar = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setarCampos();
      listarDados();
    });
  }

  @override
  void dispose() {
    super.dispose();
    _tabController?.dispose();
  }

  void listarDados() async {
    await provedor.listarCategorias().then((value) {
      _tabController = TabController(initialIndex: indexTabBar, length: value.length, vsync: this);
      _tabController!.addListener(() {
        provedor.tamanhosPizza = null;
        provedor.saboresPizzaSelecionados = [];
        setState(() => indexTabBar = _tabController!.index);
      });
    });
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
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: provedor,
      builder: (context, _) {
        final temCategorias = _tabController != null && provedor.categorias.isNotEmpty;
        return Scaffold(
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.inversePrimary,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.restaurant_menu_rounded, color: cs.onPrimaryContainer, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cardápio', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
                    Text(widget.tipo.nome, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            bottom: !temCategorias
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(48),
                    child: SizedBox(height: 48, child: Align(alignment: Alignment.bottomCenter, child: LinearProgressIndicator())),
                  )
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      ...provedor.categorias.map((e) => Tab(text: e.nomeCategoria)),
                    ],
                  ),
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
          floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
          floatingActionButton: AnimatedBuilder(
            animation: carrinhoProvedor,
            builder: (context, _) {
              final temPizza = provedor.tamanhosPizza != null && provedor.saboresPizzaSelecionados.isNotEmpty;
              return Stack(
                children: [
                  if (temPizza)
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: () {
                              if (!context.mounted) return;
                              final item = provedor.saboresPizzaSelecionados[0];
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => PaginaSaborBordas(
                                  produto: item,
                                  valorVenda: provedor.calcularPrecoPizza(),
                                ),
                              ));
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.tertiary,
                              foregroundColor: cs.onTertiary,
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              elevation: 3,
                            ),
                            icon: const Icon(Icons.local_pizza_outlined, size: 20),
                            label: Text(
                              'Avançar ${provedor.calcularPrecoPizza().obterReal()}',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 18,
                    bottom: 4,
                    child: badges.Badge(
                      badgeContent: Text(
                        carrinhoProvedor.itensCarrinho.quantidadeTotal.toStringAsFixed(0),
                        style: TextStyle(color: cs.onError, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                      badgeStyle: badges.BadgeStyle(
                        badgeColor: cs.error,
                        padding: const EdgeInsets.all(6),
                        elevation: 2,
                      ),
                      position: badges.BadgePosition.topEnd(end: -2, top: -2),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: FloatingActionButton(
                          heroTag: null,
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          elevation: 4,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => const PaginaCarrinho(),
                            ));
                          },
                          child: const Icon(Icons.shopping_cart_outlined, size: 22),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          body: !temCategorias
              ? const SizedBox.shrink()
              : DefaultTabController(
                  length: provedor.categorias.length,
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      ...provedor.categorias.map((e) {
                        listaCategorias.add(e.id);
                        return TabCustom(category: e.id, categoria: e, finalizar: finalizar);
                      }),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
