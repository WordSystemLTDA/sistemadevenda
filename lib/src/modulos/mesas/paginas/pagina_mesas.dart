import 'package:app/src/modulos/mesas/paginas/pagina_lista_mesas.dart';
import 'package:app/src/modulos/mesas/paginas/widgets/card_mesa_ocupada.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaMesas extends StatefulWidget {
  const PaginaMesas({super.key});

  @override
  State<PaginaMesas> createState() => _PaginaMesasState();
}

class _PaginaMesasState extends State<PaginaMesas> {
  final ProvedorMesas _state = Modular.get<ProvedorMesas>();
  bool isLoading = false;

  void listar() async {
    setState(() => isLoading = !isLoading);
    await _state.listarMesas('');
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();

    listar();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, child) => Scaffold(
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
                  onPressed: () {
                    // Navigator.of(context).pushNamed('/mesas/todasMesas/');
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) {
                        return const PaginaListaMesas();
                      },
                    ));
                  },
                  child: const Row(
                    children: [
                      SizedBox(width: 20),
                      Text('Mesas'),
                      SizedBox(width: 20),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async => listar(),
          child: Stack(
            children: [
              isLoading ? const LinearProgressIndicator() : const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(right: 5, left: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _state.mesas.length,
                        itemBuilder: (context, index) {
                          final item = _state.mesas[index];

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
                                itemCount: item.mesas!.length,
                                padding: const EdgeInsets.only(top: 5, bottom: 10),
                                itemBuilder: (_, index) {
                                  var itemMesa = item.mesas![index];

                                  return CardMesaOcupada(item: itemMesa);
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
