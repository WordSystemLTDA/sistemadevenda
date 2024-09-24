import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaComandaDesocupada extends StatefulWidget {
  final String id;
  final String? idComandaPedido;
  final String nome;
  const PaginaComandaDesocupada({super.key, required this.id, this.idComandaPedido, required this.nome});

  @override
  State<PaginaComandaDesocupada> createState() => _PaginaComandaDesocupadaState();
}

class _PaginaComandaDesocupadaState extends State<PaginaComandaDesocupada> {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

  final _mesaDestinoSearchController = TextEditingController();
  final _clienteSearchController = TextEditingController();
  final _obsconstroller = TextEditingController();

  bool carregando = true;

  Modeloworddadoscardapio? dados;

  String idMesa = '0';
  String idCliente = '0';

  final ProvedorComanda _state = Modular.get<ProvedorComanda>();

  @override
  void initState() {
    super.initState();
    if (widget.idComandaPedido != null) {
      listarComandasPedidos();
    } else {
      carregando = false;
    }
  }

  void listarComandasPedidos() async {
    await servicoCardapio.listarPorId(widget.idComandaPedido!, TipoCardapio.comanda).then((value) {
      setState(() {
        dados = value;
        _clienteSearchController.text = value.nomeCliente!;
        _mesaDestinoSearchController.text = value.nomeMesa!;
        _obsconstroller.text = value.observacoes!;
        idCliente = value.idCliente!;
        idMesa = value.idMesa!;
        carregando = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandas'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Visibility(
        visible: carregando == false,
        child: FloatingActionButton.extended(
          onPressed: () async {
            if (widget.idComandaPedido != null) {
              await _state.editarComandaOcupada(widget.idComandaPedido!, idMesa, idCliente, _obsconstroller.text).then((sucesso) {
                if (context.mounted) {
                  if (sucesso) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  }

                  if (!sucesso) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ocorreu um erro'),
                      showCloseIcon: true,
                    ));
                  }
                }
              });
            } else {
              await _state.inserirComandaOcupada(widget.id, idMesa, idCliente, _obsconstroller.text).then((sucesso) {
                if (context.mounted) {
                  if (sucesso) {
                    Navigator.pop(context);
                  }

                  if (!sucesso) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ocorreu um erro'),
                      showCloseIcon: true,
                    ));
                  }
                }
              });
            }
          },
          label: Row(
            children: [
              Text(widget.idComandaPedido != null ? 'Editar Comanda' : 'Abrir Comanda'),
              const SizedBox(width: 10),
              const Icon(Icons.check),
            ],
          ),
        ),
      ),
      body: Visibility(
        visible: carregando == false,
        replacement: const Center(child: CircularProgressIndicator()),
        child: GestureDetector(
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
                      onTap: () => controller.openView(),
                    );
                  },
                  suggestionsBuilder: (BuildContext context, SearchController controller) async {
                    final keyword = controller.value.text;
                    final res = await _state.listarMesas(keyword);

                    var semMesa = {'nome': 'Sem Mesa', 'id': '0'};

                    return [
                      ...[semMesa, ...res].map((e) => Card(
                            elevation: 3.0,
                            margin: const EdgeInsets.all(5.0),
                            child: InkWell(
                              onTap: () {
                                controller.closeView('');
                                _mesaDestinoSearchController.text = e['nome'];
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
                            Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) {
                                return const InserirCliente();
                              },
                            ));
                          },
                          icon: const Icon(Icons.add),
                        ),
                      ),
                      onTap: () => controller.openView(),
                    );
                  },
                  suggestionsBuilder: (BuildContext context, SearchController controller) async {
                    final keyword = controller.value.text;
                    final res = await _state.listarClientes(keyword);
                    return [
                      ...res.map(
                        (e) => Card(
                          elevation: 3.0,
                          margin: const EdgeInsets.all(5.0),
                          child: InkWell(
                            onTap: () {
                              controller.closeView('');
                              _clienteSearchController.text = e['nome'];
                              idCliente = e['id'];
                            },
                            borderRadius: const BorderRadius.all(Radius.circular(8)),
                            child: ListTile(
                              leading: const Icon(Icons.person_2_outlined),
                              title: Text(e['nome']),
                              subtitle: Text('ID: ${e['id']}'),
                            ),
                          ),
                        ),
                      ),
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
      ),
    );
  }
}
