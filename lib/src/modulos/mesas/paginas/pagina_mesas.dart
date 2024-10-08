import 'package:app/src/modulos/mesas/paginas/pagina_abrir_mesa.dart';
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
          child: ListView(
            children: [
              isLoading ? const LinearProgressIndicator() : const SizedBox(height: 4),
              if (_state.listaMesaState.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 10, left: 10, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Mesas ocupadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 3),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                          mainAxisExtent: 100,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemCount: _state.listaMesaState['mesasOcupadas']!.length,
                        itemBuilder: (context, index) {
                          final item = _state.listaMesaState['mesasOcupadas']![index];

                          return CardMesaOcupada(item: item);
                        },
                      ),
                      if (_state.listaMesaState['mesasOcupadas']!.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text('Nenhuma mesa ocupada.'),
                        ),
                      ],
                      const SizedBox(height: 5),
                      const Text('Mesas livres', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 5),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                          mainAxisExtent: 100,
                          mainAxisSpacing: 2,
                          crossAxisSpacing: 2,
                        ),
                        itemCount: _state.listaMesaState['mesasLivres']!.length,
                        itemBuilder: (context, index) {
                          final item = _state.listaMesaState['mesasLivres']![index];

                          return Card(
                            margin: const EdgeInsets.all(3),
                            child: InkWell(
                              onTap: () {
                                // Navigator.of(context).pushNamed("/mesas/abrirMesa/${item.id}/${item.nome}/");
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) {
                                    return PaginaAbrirMesa(
                                      id: item.id,
                                      nome: item.nome,
                                    );
                                  },
                                ));
                              },
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 15),
                                  const Icon(Icons.table_bar_outlined),
                                  const SizedBox(width: 10),
                                  Text(item.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      if (_state.listaMesaState['mesasLivres']!.isEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text('Nenhuma mesa livre.'),
                        ),
                      ],
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
