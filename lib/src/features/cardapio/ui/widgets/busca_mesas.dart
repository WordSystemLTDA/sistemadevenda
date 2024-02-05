// import 'package:app/src/features/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/card_produto.dart';
import 'package:flutter/material.dart';

class BuscaMesas extends StatefulWidget {
  final String tipo;
  final String idComanda;
  final String idMesa;
  const BuscaMesas({super.key, required this.tipo, required this.idComanda, required this.idMesa});

  @override
  State<BuscaMesas> createState() => _BuscaMesasState();
}

class _BuscaMesasState extends State<BuscaMesas> {
  final _searchController = SearchController();

  final ProdutoState _state = ProdutoState([]);

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: TextField(
            readOnly: true,
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
            onTap: () => _searchController.openView(),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final keyword = controller.value.text;
        final res = await _state.listarProdutosPorNome(keyword);
        return [
          ...res.map((e) => CardProduto(
                estaPesquisando: true,
                searchController: controller,
                item: e,
                tipo: widget.tipo,
                idComanda: widget.idComanda,
                idMesa: widget.idMesa,
              )),
        ];
      },
    );
  }
}
