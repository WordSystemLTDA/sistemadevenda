import 'dart:async';

import 'package:app/src/modulos/balcao/paginas/pagina_nova_venda_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/card_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaBalcao extends StatefulWidget {
  const PaginaBalcao({super.key});

  @override
  State<PaginaBalcao> createState() => _PaginaBalcaoState();
}

class _PaginaBalcaoState extends State<PaginaBalcao> {
  final ProvedorBalcao provedor = Modular.get<ProvedorBalcao>();

  final TextEditingController dataManualController = TextEditingController();
  final TextEditingController _horaController = TextEditingController();
  final TextEditingController _pesquisaController = TextEditingController();

  String dataInicial = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String dataFim = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String dataPersonalizada = 'hoje';
  Timer? _debounce;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    dataManualController.text = '${DateFormat('dd/MM/yyyy').format(DateTime.parse(dataInicial))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dataFim))}';

    _horaController.text = "0${provedor.horaSelecionado.hour}:${provedor.horaSelecionado.minute}0";
    listar();
  }

  void listar() async {
    await provedor.listar();
  }

  @override
  void dispose() {
    dataManualController.dispose();
    _horaController.dispose();
    _pesquisaController.dispose();
    if (_debounce != null) {
      _debounce!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Balcão'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              return PaginaNovaVendaBalcao(
                aoSalvar: () {},
              );
            },
          ));
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        child: const Icon(Icons.add),
      ),
      body: ListenableBuilder(
        listenable: provedor,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () async => listar(),
            child: Stack(
              children: [
                provedor.listando ? const LinearProgressIndicator() : const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(right: 5, left: 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4.0, right: 4, bottom: 8, top: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                readOnly: true,
                                controller: dataManualController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onTap: () async {
                                  DateTimeRange? picked = await showDateRangePicker(
                                    context: context,
                                    firstDate: DateTime(DateTime.now().year - 35),
                                    lastDate: DateTime(DateTime.now().year + 50),
                                    initialDateRange: DateTimeRange(
                                      start: DateTime.parse(dataInicial),
                                      end: DateTime.parse(dataFim),
                                    ),
                                  );

                                  if (picked != null) {
                                    setState(() {
                                      dataManualController.text = "${DateFormat('dd/MM/yyyy').format(picked.start)} - ${DateFormat('dd/MM/yyyy').format(picked.end)}";
                                      if (mounted) {
                                        provedor.dataSelecionada = picked;

                                        dataInicial = DateFormat('yyyy-MM-dd').format(picked.start);
                                        dataFim = DateFormat('yyyy-MM-dd').format(picked.end);
                                      }
                                    });

                                    provedor.listar(mostrarCarregamento: true);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 120,
                              child: DropdownMenu(
                                initialSelection: dataPersonalizada,
                                dropdownMenuEntries: const [
                                  DropdownMenuEntry(value: 'mes_anterior', label: 'Mês Anterior'),
                                  DropdownMenuEntry(value: 'ultimos7dias', label: 'Últimos 7 dias'),
                                  DropdownMenuEntry(value: 'ontem', label: 'Ontem'),
                                  DropdownMenuEntry(value: 'hoje', label: 'Hoje'),
                                  DropdownMenuEntry(value: 'mes_atual', label: 'Mês Atual'),
                                  DropdownMenuEntry(value: 'todos', label: 'Todos'),
                                ],
                                onSelected: (value) {
                                  dataPersonalizada = value ?? '';
                                  var agora = DateTime.now();
                                  var data = DateTimeRange(
                                    start: DateTime.parse(dataInicial),
                                    end: DateTime.parse(dataFim),
                                  );

                                  // adicionar um switch
                                  if (value == 'mes_anterior') {
                                    data = DateTimeRange(
                                      start: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
                                      end: DateTime(DateTime.now().year, DateTime.now().month, 0),
                                    );
                                  }

                                  if (value == 'ultimos7dias') {
                                    data = DateTimeRange(
                                      start: DateTime.now().subtract(const Duration(days: 7)),
                                      end: DateTime.now(),
                                    );
                                  }

                                  if (value == 'ontem') {
                                    data = DateTimeRange(
                                      start: DateTime.now().subtract(const Duration(days: 1)),
                                      end: DateTime.now().subtract(const Duration(days: 1)),
                                    );
                                  }

                                  if (value == 'hoje') {
                                    data = DateTimeRange(
                                      start: DateTime.now(),
                                      end: DateTime.now(),
                                    );
                                  }

                                  if (value == 'mes_atual') {
                                    data = DateTimeRange(start: DateTime(agora.year, agora.month, 1), end: DateTime(agora.year, agora.month + 1, 0));
                                  }

                                  if (value == 'todos') {
                                    data = DateTimeRange(start: DateTime(2000, agora.month, 1), end: DateTime.now());
                                  }

                                  setState(() {
                                    dataManualController.text = "${DateFormat('dd/MM/yyyy').format(data.start)} - ${DateFormat('dd/MM/yyyy').format(data.end)}";
                                    if (mounted) {
                                      provedor.dataSelecionada = data;
                                      dataInicial = DateFormat('yyyy-MM-dd').format(data.start);
                                      dataFim = DateFormat('yyyy-MM-dd').format(data.end);
                                    }
                                  });

                                  provedor.listar(mostrarCarregamento: true);
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 75,
                              child: TextField(
                                readOnly: true,
                                controller: _horaController,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                onTap: () async {
                                  var dataInicial =
                                      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, provedor.horaSelecionado.hour, provedor.horaSelecionado.minute);

                                  TimeOfDay? picked = await showTimePicker(
                                    context: context,
                                    initialEntryMode: TimePickerEntryMode.input,
                                    initialTime: TimeOfDay.fromDateTime(dataInicial),
                                    builder: (context, child) {
                                      return MediaQuery(
                                        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
                                              child: child,
                                            )
                                          ],
                                        ),
                                      );
                                    },
                                  );

                                  if (picked != null) {
                                    provedor.horaSelecionado = picked;
                                    _horaController.text = "${picked.hour < 10 ? '0${picked.hour}' : picked.hour}:${picked.minute < 10 ? '0${picked.minute}' : picked.minute}";

                                    provedor.listar(mostrarCarregamento: true);
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 4, right: 4, bottom: 10),
                        child: TextField(
                          controller: _pesquisaController,
                          decoration: const InputDecoration(border: OutlineInputBorder(), hintText: 'Busque aqui'),
                          onChanged: (textoPesquisa) {
                            if (_debounce?.isActive ?? false) _debounce!.cancel();

                            _debounce = Timer(const Duration(milliseconds: 500), () {
                              if (textoPesquisa.isNotEmpty) {
                                if (debounce?.isActive ?? false) {
                                  debounce!.cancel();
                                }

                                debounce = Timer(const Duration(milliseconds: 200), () async {
                                  provedor.listar(pesquisa: textoPesquisa, mostrarCarregamento: true);
                                });
                              } else {
                                provedor.listar(pesquisa: '', mostrarCarregamento: true);
                              }
                            });
                          },
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          shrinkWrap: true,
                          // gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          //   crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                          //   mainAxisExtent: 100,
                          //   mainAxisSpacing: 2,
                          //   crossAxisSpacing: 2,
                          // ),
                          scrollDirection: Axis.vertical,
                          itemCount: provedor.dados.length,
                          padding: const EdgeInsets.only(top: 5, bottom: 10),
                          itemBuilder: (_, index) {
                            var item = provedor.dados[index];

                            return CardVendasBalcao(
                              item: item,
                              listar: () {
                                listar();
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
