import 'package:app/src/essencial/widgets/custom_text_field.dart';
import 'package:app/src/modulos/listar_vendas/paginas/cadastrar_listar_vendas.dart';
import 'package:app/src/modulos/listar_vendas/provedores/provedores_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaListarVendas extends StatefulWidget {
  const PaginaListarVendas({super.key});

  @override
  State<PaginaListarVendas> createState() => _PaginaListarVendasState();
}

class _PaginaListarVendasState extends State<PaginaListarVendas> {
  final ProvedoresListarVendas _provedor = Modular.get<ProvedoresListarVendas>();

  DateTimeRange dataSelecionada = DateTimeRange(start: DateTime.now(), end: DateTime.now());
  final TextEditingController _dataController = TextEditingController();

  final _pesquisaController = TextEditingController();

  void listar() {
    _provedor.listar(
        // _pesquisaController.text,
        // dataInicial: DateFormat('yyyy-MM-dd').format(dataSelecionada.start),
        // dataFinal: DateFormat('yyyy-MM-dd').format(dataSelecionada.end),
        );
  }

  @override
  void initState() {
    super.initState();

    _dataController.text = "${DateFormat('dd/MM/yyyy').format(dataSelecionada.start)} - ${DateFormat('dd/MM/yyyy').format(dataSelecionada.end)}";

    listar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendas'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) {
                return CadastrarListarVendas(aoSalvar: () => listar());
              },
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            CustomTextField(
              readOnly: true,
              textAlign: TextAlign.center,
              controller: _dataController,
              onTap: () async {
                DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(DateTime.now().year - 20),
                  lastDate: DateTime(DateTime.now().year + 50),
                  initialDateRange: DateTimeRange(
                    end: dataSelecionada.end,
                    start: dataSelecionada.start,
                  ),
                );

                if (picked != null) {
                  setState(() {
                    dataSelecionada = picked;
                    _dataController.text = "${DateFormat('dd/MM/yyyy').format(picked.start)} - ${DateFormat('dd/MM/yyyy').format(picked.end)}";
                  });

                  listar();
                }
              },
            ),
            const SizedBox(height: 10),
            CustomTextField(
              controller: _pesquisaController,
              onChanged: (_) => listar(),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              hintText: 'Busque Aqui',
            ),
            const SizedBox(height: 10),
            ValueListenableBuilder(
              valueListenable: dados,
              builder: (context, value, child) => Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: value.length,
                  // itemCount: _provedor.dados.length,
                  itemBuilder: (context, index) {
                    final item = value[index];
                    // final item = _provedor.dados[index];

                    // id - numeroDoPedido - cp25
                    // nomeCliente
                    // formaDePagamento
                    // cp5 - horaLanc
                    // valorTotalListar
                    // stiloStatus3
                    return SizedBox(
                      height: 110,
                      child: Card(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {},
                                child: Row(
                                  children: [
                                    Container(
                                      width: 5,
                                      clipBehavior: Clip.hardEdge,
                                      decoration: const BoxDecoration(
                                        borderRadius: BorderRadius.only(
                                          topLeft: Radius.circular(8),
                                          bottomLeft: Radius.circular(8),
                                        ),
                                      ),
                                      child: const VerticalDivider(
                                        color: Colors.green,
                                        // color: item.ativo == 'Sim' ? Colors.green : Colors.red,
                                        thickness: 5,
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(left: 10, top: 9),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(item.nomeCliente),
                                          // if (item.email.isNotEmpty) ...[Text(item.email)] else ...[const Text('Sem E-mail')],
                                          // if (item.doc.isNotEmpty) ...[Text(item.doc)] else ...[const Text('Sem CPF/CNPJ')],
                                          // if (item.telefone.isNotEmpty) ...[Text(item.telefone)] else ...[const Text('Sem Telefone')],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Column(
                              children: [
                                // Expanded(
                                //   child: InkWell(
                                //     borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                                //     onTap: () async {
                                //       final res = await context.read<FornecedorProvedor>().editarAtivo(
                                //             item.id,
                                //             item.ativo == 'Sim' ? 'Não' : 'Sim',
                                //           );

                                //       if (!mounted) return;

                                //       ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                //       ScaffoldMessenger.of(context).showSnackBar(
                                //         SnackBar(
                                //           content: Text(res == 'sucesso' ? 'Fornecedor atualizado!' : 'Ocorreu um erro!'),
                                //           showCloseIcon: true,
                                //           backgroundColor: res == 'sucesso' ? Colors.green : Colors.red,
                                //         ),
                                //       );
                                //     },
                                //     child: SizedBox(
                                //       width: 50,
                                //       child: item.ativo == 'Sim'
                                //           ? const Icon(Icons.check_box_outlined)
                                //           : const Icon(Icons.check_box_outline_blank_rounded),
                                //     ),
                                //   ),
                                // ),
                                Expanded(
                                  child: InkWell(
                                    borderRadius: const BorderRadius.only(topRight: Radius.circular(8)),
                                    onTap: () {
                                      // Navigator.push(
                                      //   context,
                                      //   MaterialPageRoute(builder: (context) => CadastrarFornecedor(editar: true, dadosAEditar: item)),
                                      // );
                                    },
                                    child: const SizedBox(width: 50, child: Icon(Icons.edit)),
                                  ),
                                ),
                                Expanded(
                                  child: MenuAnchor(
                                    builder: (BuildContext context, MenuController controller, Widget? child) {
                                      return SizedBox(
                                        width: 50,
                                        child: InkWell(
                                          borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10)),
                                          onTap: () {
                                            if (controller.isOpen) {
                                              controller.close();
                                            } else {
                                              controller.open();
                                            }
                                          },
                                          child: const Icon(Icons.more_vert),
                                        ),
                                      );
                                    },
                                    menuChildren: const [
                                      // MenuItemButton(
                                      //   onPressed: () {
                                      //     showDialog(
                                      //       context: context,
                                      //       builder: (context) => Dialog(
                                      //         child: ListView(
                                      //           padding: const EdgeInsets.all(20),
                                      //           shrinkWrap: true,
                                      //           children: [
                                      //             const Text(
                                      //               'Deseja realmente excluir?',
                                      //               style: TextStyle(fontSize: 20),
                                      //             ),
                                      //             const SizedBox(height: 15),
                                      //             Expanded(
                                      //               child: Row(
                                      //                 mainAxisAlignment: MainAxisAlignment.end,
                                      //                 children: [
                                      //                   TextButton(
                                      //                     onPressed: () {
                                      //                       Navigator.pop(context);
                                      //                     },
                                      //                     child: const Text('Carcelar'),
                                      //                   ),
                                      //                   const SizedBox(width: 10),
                                      //                   TextButton(
                                      //                     onPressed: () async {
                                      //                       final res = await context.read<FornecedorProvedor>().excluir(item.id);

                                      //                       Navigator.pop(context);

                                      //                       ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      //                       ScaffoldMessenger.of(context).showSnackBar(
                                      //                         SnackBar(
                                      //                           content:
                                      //                               Text(res == 'sucesso' ? 'Fornecedor excluído!' : 'Ocorreu um erro!'),
                                      //                           showCloseIcon: true,
                                      //                           backgroundColor: res == 'sucesso' ? Colors.green : Colors.red,
                                      //                         ),
                                      //                       );
                                      //                     },
                                      //                     child: const Text('excluir'),
                                      //                   ),
                                      //                 ],
                                      //               ),
                                      //             ),
                                      //           ],
                                      //         ),
                                      //       ),
                                      //     );
                                      //   },
                                      //   child: const Row(
                                      //     children: [
                                      //       SizedBox(width: 15),
                                      //       Text(
                                      //         "Excluir",
                                      //         style: TextStyle(color: Colors.red),
                                      //       ),
                                      //       SizedBox(width: 15),
                                      //     ],
                                      //   ),
                                      // ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
