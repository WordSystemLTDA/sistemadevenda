import 'package:app/src/essencial/widgets/custom_text_field.dart';
import 'package:app/src/modulos/vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class DadosGeraisListarVendas extends StatefulWidget {
  final TextEditingController clienteController;
  final TextEditingController nomeClienteController;
  final TextEditingController naturezaController;
  final TextEditingController nomeNaturezaController;
  final TextEditingController vendedorController;
  final TextEditingController nomeVendedorController;
  final TextEditingController dataLancamentoController;

  const DadosGeraisListarVendas({
    super.key,
    required this.clienteController,
    required this.nomeClienteController,
    required this.naturezaController,
    required this.nomeNaturezaController,
    required this.vendedorController,
    required this.nomeVendedorController,
    required this.dataLancamentoController,
  });

  @override
  State<DadosGeraisListarVendas> createState() => _DadosGeraisListarVendasState();
}

class _DadosGeraisListarVendasState extends State<DadosGeraisListarVendas> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Row(
            children: [
              Expanded(
                child: SearchAnchor(
                  builder: (context, controller) {
                    return CustomTextField(
                      titulo: const Text('Cliente', style: TextStyle(fontSize: 14)),
                      readOnly: true,
                      controller: widget.nomeClienteController,
                      hintText: 'Selecione um Cliente',
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) async {
                    final pesquisa = controller.text;

                    final res = await Modular.get<ServicosListarVendas>().listarClientes(pesquisa);

                    return [
                      ...res.map((e) {
                        final element = e.nome.split(' - ');

                        return SizedBox(
                          height: 80,
                          child: Card(
                            child: InkWell(
                              borderRadius: const BorderRadius.all(Radius.circular(8)),
                              onTap: () {
                                controller.closeView(e.nome);
                                widget.nomeClienteController.text = element.first;
                                widget.clienteController.text = e.id;
                              },
                              child: ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(element.first),
                                subtitle: Text(element.length >= 2 ? element[1] : 'Sem CPF'),
                              ),
                            ),
                          ),
                        );
                      }),
                    ];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              Expanded(
                child: SearchAnchor(
                  builder: (context, controller) {
                    return CustomTextField(
                      titulo: const Text('Natureza', style: TextStyle(fontSize: 14)),
                      readOnly: true,
                      controller: widget.nomeNaturezaController,
                      hintText: 'Selecione um Natureza',
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) async {
                    final pesquisa = controller.text;

                    final res = await Modular.get<ServicosListarVendas>().listarNatureza(pesquisa);

                    return [
                      ...res.map((e) => SizedBox(
                            height: 80,
                            child: Card(
                              child: InkWell(
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                onTap: () {
                                  controller.closeView(e.nome);
                                  widget.nomeNaturezaController.text = e.nome;
                                  widget.naturezaController.text = e.id;
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(e.nome),
                                  subtitle: Text('ID: ${e.id}'),
                                ),
                              ),
                            ),
                          )),
                    ];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              Expanded(
                child: SearchAnchor(
                  builder: (context, controller) {
                    return CustomTextField(
                      titulo: const Text('Vendedor', style: TextStyle(fontSize: 14)),
                      readOnly: true,
                      controller: widget.nomeVendedorController,
                      hintText: 'Selecione um Vendedor',
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) async {
                    final pesquisa = controller.text;

                    final res = await Modular.get<ServicosListarVendas>().listarVendedor(pesquisa);

                    return [
                      ...res.map((e) => SizedBox(
                            height: 80,
                            child: Card(
                              child: InkWell(
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                onTap: () {
                                  controller.closeView(e.nome);
                                  widget.nomeVendedorController.text = e.nome;
                                  widget.vendedorController.text = e.id;
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(e.nome),
                                  subtitle: Text('ID: ${e.id}'),
                                ),
                              ),
                            ),
                          )),
                    ];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 1),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: widget.dataLancamentoController,
                  titulo: const Text('Data Lançamento', style: TextStyle(fontSize: 14)),
                  hintText: 'Data Lançamento',
                  readOnly: true,
                  onTap: () async {
                    final DateTime? time = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                      initialDate: DateTime.now(),
                    );

                    if (time != null) {
                      setState(() {
                        widget.dataLancamentoController.text = DateFormat('dd/MM/yyyy').format(time).toString();
                      });
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
