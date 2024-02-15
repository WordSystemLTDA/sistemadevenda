import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';
import 'package:app/src/features/comandas/ui/widgets/comanda_desocupada_dialog.dart';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ComandasPage extends StatefulWidget {
  const ComandasPage({super.key});

  @override
  State<ComandasPage> createState() => _ComandasPageState();
}

class _ComandasPageState extends State<ComandasPage> {
  final ComandasState _state = ComandasState();
  bool isLoading = false;

  void listarComandas() async {
    setState(() => isLoading = !isLoading);
    await _state.listarComandas();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: listarComandas,
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: comandasState,
        builder: (context, value, child) => Stack(
          children: [
            if (isLoading) const LinearProgressIndicator(),
            Padding(
              padding: const EdgeInsets.only(top: 10, right: 10, left: 10),
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
                            Text(item.titulo),
                            GridView.builder(
                              physics: const NeverScrollableScrollPhysics(),
                              shrinkWrap: true,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                                mainAxisExtent: 70,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                              ),
                              scrollDirection: Axis.vertical,
                              itemCount: item.comandas!.length,
                              padding: const EdgeInsets.only(top: 5, bottom: 10),
                              itemBuilder: (_, index) {
                                var itemComanda = item.comandas![index];
                                return Card(
                                  child: InkWell(
                                    onTap: () {
                                      if (!itemComanda.comandaOcupada) {
                                        showDialog(
                                          context: context,
                                          builder: (context) => ComandaDesocupadaDialog(id: itemComanda.id),
                                        );
                                      } else {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return SizedBox(
                                              child: Dialog(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(10),
                                                  child: Column(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        children: [
                                                          Card(
                                                            child: SizedBox(
                                                              width: (MediaQuery.of(context).size.width - 120) / 2,
                                                              height: (MediaQuery.of(context).size.width - 120) / 2,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  Modular.to.pushNamed('/cardapio/Comanda/${itemComanda.id}/0');
                                                                  Navigator.pop(context);
                                                                },
                                                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                                child: const Center(child: Icon(Icons.add)),
                                                              ),
                                                            ),
                                                          ),
                                                          Card(
                                                            child: SizedBox(
                                                              width: (MediaQuery.of(context).size.width - 120) / 2,
                                                              height: (MediaQuery.of(context).size.width - 120) / 2,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  Navigator.pop(context);
                                                                },
                                                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                                child: const Center(child: Icon(Icons.production_quantity_limits)),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      Row(
                                                        children: [
                                                          Card(
                                                            child: SizedBox(
                                                              width: (MediaQuery.of(context).size.width - 120) / 2,
                                                              height: (MediaQuery.of(context).size.width - 120) / 2,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  Navigator.pop(context);
                                                                },
                                                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                                child: const Center(child: Icon(Icons.print)),
                                                              ),
                                                            ),
                                                          ),
                                                          Card(
                                                            child: SizedBox(
                                                              width: (MediaQuery.of(context).size.width - 120) / 2,
                                                              height: (MediaQuery.of(context).size.width - 120) / 2,
                                                              child: InkWell(
                                                                onTap: () {
                                                                  Navigator.pop(context);
                                                                },
                                                                borderRadius: const BorderRadius.all(Radius.circular(10)),
                                                                child: const Center(child: Icon(Icons.edit)),
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      )
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      }
                                    },
                                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        const SizedBox(width: 15),
                                        const Icon(Icons.topic_outlined),
                                        // const Icon(Icons.fact_check_outlined),
                                        const SizedBox(width: 10),
                                        Text(itemComanda.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                );
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
    );
  }
}
