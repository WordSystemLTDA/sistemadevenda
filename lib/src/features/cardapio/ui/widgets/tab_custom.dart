import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/card_produto.dart';
import 'package:flutter/material.dart';

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

  final ProdutoState _state = ProdutoState([]);

  void listarProdutos(categoria) async {
    _state.listarProdutosPorCategoria(categoria);
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
      child: ValueListenableBuilder(
        valueListenable: _state,
        builder: (context, value, child) {
          List<ProdutoModel> listaProdutos = [];

          value.map((e) => e.categoria == widget.category ? listaProdutos = e.listaProdutos : listaProdutos = []).toList();

          return listaProdutos.isEmpty
              ? ListView(
                  children: const [SizedBox(height: 100, child: Center(child: Text('Não há Itens')))],
                )
              : ListView.builder(
                  itemCount: listaProdutos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == listaProdutos.length) {
                      return const SizedBox(height: 80, child: Center(child: Text('Fim da Lista')));
                    }
                    final item = listaProdutos[index];

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
