import 'package:app/src/modulos/comandas/interactor/states/comandas_state.dart';
import 'package:app/src/modulos/comandas/ui/todas_comanadas.dart';
import 'package:app/src/modulos/comandas/ui/widgets/card_comanda.dart';
import 'package:flutter/material.dart';

class PaginaComandas extends StatefulWidget {
  const PaginaComandas({super.key});

  @override
  State<PaginaComandas> createState() => _PaginaComandasState();
}

class _PaginaComandasState extends State<PaginaComandas> {
  final ComandasState _state = ComandasState();
  bool isLoading = false;

  void listarComandas() async {
    setState(() => isLoading = !isLoading);
    await _state.listarComandas('');
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();
    listarComandas();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandas'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          MenuAnchor(
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return IconButton(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.more_horiz),
              );
            },
            menuChildren: [
              MenuItemButton(
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TodasComandas()));
                },
                child: const Row(
                  children: [
                    SizedBox(width: 20),
                    Text('Comandas'),
                    SizedBox(width: 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: comandasState,
        builder: (context, value, child) => RefreshIndicator(
          onRefresh: () async => listarComandas(),
          child: Stack(
            children: [
              if (isLoading) const LinearProgressIndicator(),
              Padding(
                padding: const EdgeInsets.only(right: 5, left: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: value.length,
                        itemBuilder: (context, index) {
                          final item = value[index];

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              Text('${item.titulo}:', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                shrinkWrap: true,
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                                  mainAxisExtent: 100,
                                  mainAxisSpacing: 2,
                                  crossAxisSpacing: 2,
                                ),
                                scrollDirection: Axis.vertical,
                                itemCount: item.comandas!.length,
                                padding: const EdgeInsets.only(top: 5, bottom: 10),
                                itemBuilder: (_, index) {
                                  var itemComanda = item.comandas![index];

                                  return CardComanda(itemComanda: itemComanda);
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
