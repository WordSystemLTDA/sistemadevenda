// import 'package:app/src/modulos/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class BuscaMesas extends StatefulWidget {
  final String tipo;
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;
  const BuscaMesas({super.key, required this.tipo, required this.idComanda, required this.idComandaPedido, required this.idMesa});

  @override
  State<BuscaMesas> createState() => _BuscaMesasState();
}

class _BuscaMesasState extends State<BuscaMesas> {
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final _searchController = SearchController();

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _searchController,
      builder: (BuildContext context, SearchController controller) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TextField(
              readOnly: true,
              decoration: InputDecoration(
                filled: true,
                border: InputBorder.none,
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
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        final keyword = controller.value.text;
        final res = await provedorCardapio.listarProdutosPorNome(keyword);
        return [
          ...res.map(
            (e) => CardProduto(
              estaPesquisando: true,
              searchController: controller,
              item: e,
              tipo: widget.tipo,
              idComandaPedido: widget.idComandaPedido,
              idComanda: widget.idComanda,
              idMesa: widget.idMesa,
            ),
          ),
        ];
      },
    );
  }
}
