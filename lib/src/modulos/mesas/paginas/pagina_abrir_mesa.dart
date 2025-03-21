import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaAbrirMesa extends StatefulWidget {
  final String id;
  final String nome;
  const PaginaAbrirMesa({super.key, required this.id, required this.nome});

  @override
  State<PaginaAbrirMesa> createState() => _PaginaAbrirMesaState();
}

class _PaginaAbrirMesaState extends State<PaginaAbrirMesa> {
  final _clienteSearchController = SearchController();
  final _obsconstroller = TextEditingController();

  String idCliente = '0';

  final ProvedorMesas _state = Modular.get<ProvedorMesas>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Abrir Mesa'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await _state.inserirMesaOcupada(widget.id, idCliente, _obsconstroller.text).then((sucesso) {
            if (context.mounted) {
              final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
              provedorMesas.listarMesas('');

              if (context.mounted) {
                Navigator.pop(context);
              }
            }

            if (context.mounted && !sucesso.sucesso) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ocorreu um erro'),
                showCloseIcon: true,
              ));
            }
          });
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
          child: ListView(
            children: [
              Row(
                children: [
                  const Icon(Icons.table_bar_outlined, size: 44),
                  const SizedBox(width: 10),
                  Text(widget.nome, style: const TextStyle(fontSize: 22)),
                ],
              ),
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
                          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const InserirCliente()));
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
              SizedBox(
                height: 150,
                child: TextField(
                  maxLines: 4,
                  controller: _obsconstroller,
                  decoration: const InputDecoration(
                    hintText: 'Observação',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
