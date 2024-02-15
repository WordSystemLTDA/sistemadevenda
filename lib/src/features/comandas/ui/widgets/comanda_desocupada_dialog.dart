import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';
import 'package:flutter/material.dart';

class ComandaDesocupadaDialog extends StatefulWidget {
  final String id;
  const ComandaDesocupadaDialog({super.key, required this.id});

  @override
  State<ComandaDesocupadaDialog> createState() => _ComandaDesocupadaStateDialog();
}

class _ComandaDesocupadaStateDialog extends State<ComandaDesocupadaDialog> {
  final _mesaDestinoSearchController = SearchController();
  final _clienteSearchController = SearchController();
  final _obsconstroller = TextEditingController();

  String idMesa = '0';
  String idCliente = '0';

  final ComandasState _state = ComandasState();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: Dialog(
        child: InkWell(
          focusColor: Colors.transparent,
          splashColor: Colors.transparent,
          splashFactory: NoSplash.splashFactory,
          highlightColor: Colors.transparent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: Padding(
            padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchAnchor(
                  searchController: _mesaDestinoSearchController,
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      controller: _mesaDestinoSearchController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Mesa de Destino',
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
                SearchAnchor(
                  searchController: _clienteSearchController,
                  builder: (BuildContext context, SearchController controller) {
                    return TextField(
                      controller: _clienteSearchController,
                      readOnly: true,
                      decoration: const InputDecoration(
                        contentPadding: EdgeInsets.all(12),
                        border: OutlineInputBorder(),
                        isDense: true,
                        hintText: 'Cliente',
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
                TextField(
                  controller: _obsconstroller,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.all(12),
                    border: OutlineInputBorder(),
                    isDense: true,
                    hintText: 'Observação',
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Carcelar'),
                    ),
                    const SizedBox(width: 10),
                    TextButton(
                      onPressed: () async {
                        final res = await _state.inserirComandaOcupada(widget.id, idMesa, idCliente, _obsconstroller.text);

                        Navigator.pop(context);

                        if (!res) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Ocorreu um erro'),
                            showCloseIcon: true,
                          ));
                        }
                      },
                      child: const Text('Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
