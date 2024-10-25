import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/lista_tamanhos_pizza.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final ModeloCategoria categoria;
  final String? idComanda;
  final String? idComandaPedido;
  final String idMesa;
  final TipoCardapio tipo;
  const TabCustom({super.key, required this.category, required this.categoria, this.idComanda, this.idComandaPedido, required this.idMesa, required this.tipo});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ProvedorProdutos provedor = Modular.get<ProvedorProdutos>();

  ValueNotifier<bool> carregando = ValueNotifier(true);

  void listarProdutos(categoria) async {
    await provedor.listarProdutosPorCategoria(categoria);
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
      child: ListenableBuilder(
        listenable: provedor,
        builder: (context, _) {
          return Column(
            children: [
              if (widget.categoria.tamanhosPizza != null && widget.categoria.tamanhosPizza!.isNotEmpty) ...[
                ListaTamanhosPizza(categoria: widget.categoria),
              ],
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: carregando,
                  builder: (context, valueCarregando, _) {
                    if (valueCarregando == true) {
                      return const Center(child: CircularProgressIndicator());
                    } else {
                      if (provedor.produtos.isEmpty && valueCarregando == false) {
                        return ListView(
                          shrinkWrap: true,
                          children: const [SizedBox(height: 100, child: Center(child: Text('Não há Itens')))],
                        );
                      } else {
                        return ListView.builder(
                          shrinkWrap: true,
                          itemCount: provedor.produtos.length + 1,
                          itemBuilder: (context, index) {
                            if (index == provedor.produtos.length) {
                              return const SizedBox(height: 80, child: Center(child: Text('Fim da Lista')));
                            }

                            final item = provedor.produtos[index];

                            return CardProduto(
                              estaPesquisando: false,
                              item: item,
                              categoria: widget.categoria,
                              tipo: widget.tipo,
                              idComandaPedido: widget.idComandaPedido!,
                              idComanda: widget.idComanda!,
                              idMesa: widget.idMesa,
                            );
                          },
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
