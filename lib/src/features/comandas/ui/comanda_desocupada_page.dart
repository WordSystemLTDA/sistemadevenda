import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';
import 'package:app/src/features/comandas/ui/inserir_cliente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ComandaDesocupadaPage extends StatefulWidget {
  final String id;
  final String nome;
  const ComandaDesocupadaPage({super.key, required this.id, required this.nome});

  @override
  State<ComandaDesocupadaPage> createState() => _ComandaDesocupadaPageState();
}

class _ComandaDesocupadaPageState extends State<ComandaDesocupadaPage> {
  final _mesaDestinoSearchController = SearchController();
  final _clienteSearchController = SearchController();
  final _obsconstroller = TextEditingController();

  String idMesa = '0';
  String idCliente = '0';

  final ComandasState _state = ComandasState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandas'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await _state.inserirComandaOcupada(widget.id, idMesa, idCliente, _obsconstroller.text);

          if (mounted) {
            if (res) {
              Navigator.pop(context);
            }

            if (!res) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ocorreu um erro'),
                showCloseIcon: true,
              ));
            }
          }
        },
        label: const Row(
          children: [
            Text('Salvar'),
            SizedBox(width: 10),
            Icon(Icons.check),
          ],
        ),
      ),
      body: InkWell(
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.fact_check_outlined, size: 44),
                  const SizedBox(width: 10),
                  Text(widget.nome, style: const TextStyle(fontSize: 22)),
                ],
              ),
              const SizedBox(height: 10),
              const Text('Mesa de Destino', style: TextStyle(fontSize: 18)),
              SearchAnchor(
                searchController: _mesaDestinoSearchController,
                builder: (BuildContext context, SearchController controller) {
                  return TextField(
                    controller: _mesaDestinoSearchController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      // contentPadding: EdgeInsets.all(12),
                      border: UnderlineInputBorder(),
                      isDense: true,
                      hintText: 'Selecione a Mesa de Destino',
                    ),
                    onTap: () => _mesaDestinoSearchController.openView(),
                  );
                },
                suggestionsBuilder: (BuildContext context, SearchController controller) async {
                  final keyword = controller.value.text;
                  final res = await _state.listarMesas(keyword);

                  return [
                    ...res.map((e) => Card(
                          elevation: 3.0,
                          margin: const EdgeInsets.all(5.0),
                          child: InkWell(
                            onTap: () {
                              _mesaDestinoSearchController.closeView(e['nome']);
                              idMesa = e['id'];
                            },
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                            child: ListTile(
                              leading: const Icon(Icons.table_bar_outlined),
                              title: Text(e['nome']),
                              subtitle: Text('ID: ${e['id']}'),
                            ),
                          ),
                        )),
                  ];
                },
              ),
              const SizedBox(height: 10),
              const Text('Cliente', style: TextStyle(fontSize: 18)),
              SearchAnchor(
                searchController: _clienteSearchController,
                builder: (BuildContext context, SearchController controller) {
                  return TextField(
                    controller: _clienteSearchController,
                    readOnly: true,
                    decoration: InputDecoration(
                      border: const UnderlineInputBorder(),
                      isDense: true,
                      hintText: 'Selecione o Cliente',
                      suffixIcon: IconButton(
                        onPressed: () {
                          Modular.to.push(MaterialPageRoute(builder: (context) => const InserirCliente()));
                        },
                        icon: const Icon(Icons.add),
                      ),
                    ),
                    onTap: () => _clienteSearchController.openView(),
                  );
                },
                suggestionsBuilder: (BuildContext context, SearchController controller) async {
                  final keyword = controller.value.text;
                  final res = await _state.listarClientes(keyword);
                  return [
                    ...res.map((e) => Card(
                          elevation: 3.0,
                          margin: const EdgeInsets.all(5.0),
                          child: InkWell(
                            onTap: () {
                              _clienteSearchController.closeView(e['nome']);
                              idCliente = e['id'];
                            },
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                            child: ListTile(
                              leading: const Icon(Icons.person_2_outlined),
                              title: Text(e['nome']),
                              subtitle: Text('ID: ${e['id']}'),
                            ),
                          ),
                        )),
                  ];
                },
              ),
              const SizedBox(height: 10),
              const Text('Observação', style: TextStyle(fontSize: 18)),
              TextField(
                controller: _obsconstroller,
                decoration: const InputDecoration(
                  border: UnderlineInputBorder(),
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
