import 'package:flutter/material.dart';

class ComandaDesocupadaDialog extends StatefulWidget {
  const ComandaDesocupadaDialog({super.key});

  @override
  State<ComandaDesocupadaDialog> createState() => _ComandaDesocupadaStateDialog();
}

class _ComandaDesocupadaStateDialog extends State<ComandaDesocupadaDialog> {
  final _mesaDestinoSearchController = SearchController();
  final _clienteSearchController = SearchController();
  final _obsconstroller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Dialog(
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Salvar em  -- comandas_pedidos -- \\
              SearchAnchor(
                searchController: _mesaDestinoSearchController,
                builder: (BuildContext context, SearchController controller) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: TextField(
                      controller: _mesaDestinoSearchController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Mesa de Destino',
                      ),
                      onTap: () => _mesaDestinoSearchController.openView(),
                    ),
                  );
                },
                suggestionsBuilder: (BuildContext context, SearchController controller) async {
                  final keyword = controller.value.text;
                  // final res = await _state.listarProdutosPorNome(keyword);
                  return [
                    // ...res.map((e) => CardProduto(
                    //       estaPesquisando: true,
                    //       searchController: controller,
                    //       item: e,
                    //       tipo: widget.tipo,
                    //       idComanda: widget.idComanda,
                    //       idMesa: widget.idMesa,
                    //     )),
                  ];
                },
              ),
              // TextField(
              //   controller: constroller,
              //   decoration: const InputDecoration(
              //     border: OutlineInputBorder(),
              //     isDense: true,
              //     hintText: 'Mesa de Destino',
              //   ),
              // ),
              TextField(
                controller: _clienteSearchController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Cliente',
                ),
              ),
              TextField(
                controller: _obsconstroller,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                  hintText: 'Obs',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
