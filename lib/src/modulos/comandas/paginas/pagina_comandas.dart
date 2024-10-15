import 'dart:async';

import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaComandas extends StatefulWidget {
  const PaginaComandas({super.key});

  @override
  State<PaginaComandas> createState() => _PaginaComandasState();
}

class _PaginaComandasState extends State<PaginaComandas> {
  final ProvedorComanda _state = Modular.get<ProvedorComanda>();
  bool isLoading = false;
  Timer? _timer;

  void listarComandas() async {
    setState(() => isLoading = !isLoading);
    await _state.listarComandas('');
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();
    listarComandas();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      listarComandas();
    });
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }
    super.dispose();
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
      body: ListenableBuilder(
        listenable: _state,
        builder: (context, child) {
          return RefreshIndicator(
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
                          itemCount: _state.comandas.length,
                          itemBuilder: (context, index) {
                            final item = _state.comandas[index];

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
          );
        },
      ),
    );
  }
}
