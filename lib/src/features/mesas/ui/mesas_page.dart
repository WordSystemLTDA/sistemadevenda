import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';
import 'package:app/src/features/mesas/ui/mesa_desocupada_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class MesasPage extends StatefulWidget {
  const MesasPage({super.key});

  @override
  State<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends State<MesasPage> {
  final MesaState _state = MesaState();
  bool isLoading = false;

  void listar() async {
    setState(() => isLoading = !isLoading);
    await _state.listarMesas();
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();

    listar();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: listaMesaState,
      builder: (context, value, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Mesas'),
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
                  onPressed: () {},
                  child: const Row(
                    children: [
                      SizedBox(width: 20),
                      Text('Nova Mesa'),
                      SizedBox(width: 20),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        // mesaOcupada
        body: RefreshIndicator(
          onRefresh: () async => listar(),
          child: SingleChildScrollView(
            child: Column(
              children: [
                isLoading ? const LinearProgressIndicator() : const SizedBox(height: 4),
                if (value.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Mesas ocupadas', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 3),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                            mainAxisExtent: 70,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          itemCount: value['mesasOcupadas'].length,
                          itemBuilder: (context, index) {
                            final item = value['mesasOcupadas'][index];

                            return Card(
                              color: Theme.of(context).colorScheme.inversePrimary,
                              child: InkWell(
                                onTap: () {
                                  Modular.to.pushNamed('/cardapio/Mesa/0/${item["id"]}');
                                },
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 15),
                                    const Icon(Icons.table_bar_outlined),
                                    const SizedBox(width: 10),
                                    Text(item['nome'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 3),
                        const Text('Mesas livres', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 5),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                            mainAxisExtent: 70,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          itemCount: value['mesasLivres'].length,
                          itemBuilder: (context, index) {
                            final item = value['mesasLivres'][index];

                            return Card(
                              child: InkWell(
                                onTap: () {
                                  Modular.to.push(
                                    MaterialPageRoute(
                                      builder: (context) => MesaDesocupadaPage(
                                        id: item['id'],
                                        nome: item['nome'],
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const SizedBox(width: 15),
                                    const Icon(Icons.table_bar_outlined),
                                    const SizedBox(width: 10),
                                    Text(item['nome'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
