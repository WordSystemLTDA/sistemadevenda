import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedor/provedor_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final String? idComanda;
  final String idMesa;
  final String tipo;
  const TabCustom({super.key, required this.category, this.idComanda, required this.idMesa, required this.tipo});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final CardapioProvedor cardapioProvedor = Modular.get<CardapioProvedor>();

  void listarProdutos(categoria) async {
    cardapioProvedor.listarProdutosPorCategoria(categoria);
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
        animation: cardapioProvedor,
        builder: (context, _) {
          return cardapioProvedor.produtos.isEmpty
              ? ListView(
                  children: const [SizedBox(height: 100, child: Center(child: Text('Não há Itens')))],
                )
              : ListView.builder(
                  itemCount: cardapioProvedor.produtos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == cardapioProvedor.produtos.length) {
                      return const SizedBox(height: 80, child: Center(child: Text('Fim da Lista')));
                    }
                    final item = cardapioProvedor.produtos[index];

                    return CardProduto(
                      estaPesquisando: false,
                      item: item,
                      tipo: widget.tipo,
                      idComanda: widget.idComanda!,
                      idMesa: widget.idMesa,
                    );
                  },
                );
        },
      ),
    );
  }
}
