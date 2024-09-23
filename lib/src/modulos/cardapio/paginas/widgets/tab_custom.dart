import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final String? idComanda;
  final String? idComandaPedido;
  final String idMesa;
  final String tipo;
  const TabCustom({super.key, required this.category, this.idComanda, this.idComandaPedido, required this.idMesa, required this.tipo});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  ValueNotifier<bool> carregando = ValueNotifier(true);

  void listarProdutos(categoria) async {
    await provedorCardapio.listarProdutosPorCategoria(categoria);
    carregando.value = false;
  }

  void pesquisarProdutos(categoria) {
    listarProdutos(categoria);
  }

  @override
  void initState() {
    super.initState();
    listarProdutos(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async => listarProdutos(widget.category),
      child: AnimatedBuilder(
        animation: provedorCardapio,
        builder: (context, _) {
          return ValueListenableBuilder(
            valueListenable: carregando,
            builder: (context, valueCarregando, _) {
              return valueCarregando == true
                  ? const Align(alignment: Alignment(0, -0.9), child: CircularProgressIndicator())
                  : provedorCardapio.produtos.isEmpty && valueCarregando == false
                      ? ListView(
                          children: const [SizedBox(height: 100, child: Center(child: Text('Não há Itens')))],
                        )
                      : ListView.builder(
                          itemCount: provedorCardapio.produtos.length + 1,
                          itemBuilder: (context, index) {
                            if (index == provedorCardapio.produtos.length) {
                              return const SizedBox(height: 80, child: Center(child: Text('Fim da Lista')));
                            }

                            final item = provedorCardapio.produtos[index];

                            return CardProduto(
                              estaPesquisando: false,
                              item: item,
                              tipo: widget.tipo,
                              idComandaPedido: widget.idComandaPedido!,
                              idComanda: widget.idComanda!,
                              idMesa: widget.idMesa,
                            );
                          },
                        );
            },
          );
        },
      ),
    );
  }
}
