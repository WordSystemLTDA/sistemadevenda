// ignore_for_file: public_member_api_docs, sort_constructors_first
// import 'package:app/src/modulos/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_produtos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class BuscarProdutos extends StatefulWidget {
  final ModeloCategoria? categoria;
  final String idcliente;

  const BuscarProdutos({
    super.key,
    required this.categoria,
    required this.idcliente,
  });

  @override
  State<BuscarProdutos> createState() => _BuscarProdutosState();
}

class _BuscarProdutosState extends State<BuscarProdutos> {
  final ProvedorProdutos provedor = Modular.get<ProvedorProdutos>();
  final _searchController = SearchController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
              // readOnly: true,
              decoration: InputDecoration(
                filled: true,
                border: InputBorder.none,
                fillColor: Colors.white,
                hintText: 'Pesquisar...',
                prefixIcon: IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                    provedor.resetarTudo();
                  },
                  icon: const Icon(Icons.arrow_back_outlined),
                ),
              ),
              onChanged: (value) async {
                provedor.listarProdutosPorNome(value, widget.categoria!.id, widget.idcliente);
              },
              // onTap: () => _searchController.openView(),
            ),
          ),
        );
      },
      suggestionsBuilder: (BuildContext context, SearchController controller) async {
        if (widget.categoria == null) return [];

        // final keyword = controller.value.text;
        // final res = await provedor.listarProdutosPorNome(keyword, widget.categoria!.id, widget.idcliente);

        return [
          // ...res.map(
          //   (e) => CardProduto(
          //     estaPesquisando: true,
          //     searchController: controller,
          //     item: e,
          //     categoria: widget.categoria,
          //   ),
          // ),
        ];
      },
    );
  }
}
