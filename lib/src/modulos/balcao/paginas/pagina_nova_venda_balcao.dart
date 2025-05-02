import 'package:app/src/modulos/balcao/modelos/modelo_enderecos_clientes.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/inserir_cliente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaNovaVendaBalcao extends StatefulWidget {
  final Function() aoSalvar;

  const PaginaNovaVendaBalcao({
    super.key,
    required this.aoSalvar,
  });

  @override
  State<PaginaNovaVendaBalcao> createState() => _PaginaNovaVendaBalcaoState();
}

class _PaginaNovaVendaBalcaoState extends State<PaginaNovaVendaBalcao> {
  final ProvedorBalcao provedor = Modular.get<ProvedorBalcao>();

  final TextEditingController obsController = TextEditingController();
  final TextEditingController clienteController = TextEditingController(text: '');
  final TextEditingController enderecoController = TextEditingController(text: '');

  String idCliente = '0';
  String idEnderecoCliente = '0';
  String tipoentrega = '3';

  @override
  void initState() {
    super.initState();
    // listarDados();
  }

  @override
  void dispose() {
    obsController.dispose();
    clienteController.dispose();
    enderecoController.dispose();
    super.dispose();
  }

  bool verificarAbrirComanda() {
    if (idCliente.isEmpty) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    double width = 1000;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Nova Venda Balcão"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: SizedBox(
        width: 150,
        child: FloatingActionButton.extended(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          onPressed: () {
            abrir();
          },
          label: const Text('Abrir'),
        ),
      ),
      body: SizedBox(
        width: width,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: LayoutBuilder(
            builder: (context, constraints) => Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cliente', style: TextStyle(fontSize: 18)),
                    SearchAnchor(
                      builder: (BuildContext context, SearchController controller) {
                        return TextField(
                          controller: clienteController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            // isDense: true,
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
                        final res = await provedor.listarClientes(keyword);
                        return [
                          ...res.map(
                            (e) => Card(
                              elevation: 3.0,
                              margin: const EdgeInsets.all(5.0),
                              child: InkWell(
                                onTap: () async {
                                  controller.closeView('');
                                  clienteController.text = e['nome'];
                                  idCliente = e['id'];

                                  List<Modelowordenderecosclientes>? enderecos = await provedor.listarEnderecosClientes('', idCliente);

                                  if (enderecos.where((element) => element.padrao == 'Sim').isNotEmpty) {
                                    var end = enderecos.where((element) => element.padrao == 'Sim').first;
                                    enderecoController.text = "${end.endereco} ${end.bairro.isNotEmpty ? "- ${end.bairro} -" : ''} ${end.numero}";
                                    idEnderecoCliente = end.id;
                                  } else {
                                    enderecoController.text = 'Sem Endereço';
                                  }
                                  setState(() {});
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
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Endereço de Entrega', style: TextStyle(fontSize: 18)),
                    SearchAnchor(
                      builder: (BuildContext context, SearchController controller) {
                        return TextField(
                          controller: enderecoController,
                          readOnly: true,
                          decoration: InputDecoration(
                            border: const UnderlineInputBorder(),
                            // isDense: true,
                            hintText: 'Selecione um Endereço',
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
                        final res = await provedor.listarEnderecosClientes(keyword, idCliente);
                        return [
                          ...res.map(
                            (e) => Card(
                              elevation: 3.0,
                              margin: const EdgeInsets.all(5.0),
                              child: InkWell(
                                onTap: () {
                                  controller.closeView('');
                                  var endereco = e;

                                  enderecoController.text = "${endereco.endereco} ${endereco.bairro.isNotEmpty ? "- ${endereco.bairro} -" : '-'} ${endereco.numero}";
                                  idEnderecoCliente = endereco.id;
                                },
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                child: ListTile(
                                  leading: const Icon(Icons.person_2_outlined),
                                  title: Text("${e.endereco} ${e.bairro.isNotEmpty ? "- ${e.bairro} -" : '-'} ${e.numero}"),
                                  subtitle: Text('ID: ${e.id}'),
                                ),
                              ),
                            ),
                          ),
                        ];
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tipo de Entrega', style: TextStyle(fontSize: 18)),
                    DropdownMenu(
                      width: (constraints.maxWidth),
                      hintText: 'Selecione um Tipo de Entrega',
                      initialSelection: tipoentrega,
                      inputDecorationTheme: const InputDecorationTheme(
                        border: UnderlineInputBorder(),
                      ),
                      dropdownMenuEntries: const [
                        DropdownMenuEntry(value: '3', label: 'Consumir no Local'),
                        DropdownMenuEntry(value: '2', label: 'Retirar no Balcão'),
                      ],
                      onSelected: (value) {
                        if (value != null) {
                          tipoentrega = value;
                        } else {
                          tipoentrega = '0';
                        }
                      },
                      // titulo: const Text('Tipo de Entrega'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Observação', style: TextStyle(fontSize: 18)),
                    TextField(
                      controller: obsController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                      ),
                      // titulo: const Text('Observação'),
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

  void abrir() async {
    provedor.observacaoDoPedido = obsController.text;

    Navigator.push(context, MaterialPageRoute(
      builder: (context) {
        return PaginaCardapio(
          tipo: TipoCardapio.balcao,
          idCliente: idCliente,
          tipodeentrega: tipoentrega,
        );
      },
    ));
  }
}
