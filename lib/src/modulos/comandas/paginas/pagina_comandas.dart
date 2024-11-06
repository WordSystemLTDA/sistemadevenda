import 'dart:async';

import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PaginaComandas extends StatefulWidget {
  const PaginaComandas({super.key});

  @override
  State<PaginaComandas> createState() => _PaginaComandasState();
}

class _PaginaComandasState extends State<PaginaComandas> {
  final MobileScannerController controller = MobileScannerController(
      // required options for the scanner

      );

  Timer? debounce;
  Timer? _debounce;

  final ProvedorComanda provedor = Modular.get<ProvedorComanda>();
  bool isLoading = false;
  Timer? _timer;
  String opcaoFiltro = 'Ocupadas';

  void listarComandas() async {
    setState(() => isLoading = !isLoading);
    await provedor.listarComandas('');
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();
    listarComandas();
  }

  @override
  void dispose() {
    if (_timer != null) {
      _timer!.cancel();
    }
    if (debounce != null) {
      debounce?.cancel();
    }
    if (_debounce != null) {
      _debounce?.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comandas'),
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
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TodasComandas()));
                },
                child: const Row(
                  children: [
                    SizedBox(width: 20),
                    Text('Comandas'),
                    SizedBox(width: 20),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: provedor,
        builder: (context, child) {
          return RefreshIndicator(
            onRefresh: () async => listarComandas(),
            child: Visibility(
              visible: isLoading == false,
              replacement: const Center(child: CircularProgressIndicator()),
              child: Stack(
                children: [
                  DefaultTabController(
                    length: provedor.comandas.isNotEmpty ? (provedor.comandas.length + 1) : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            tabAlignment: TabAlignment.fill,
                            labelPadding: const EdgeInsets.only(right: 10, left: 10),
                            // isScrollable: true,
                            tabs: [
                              SizedBox(
                                height: 40,
                                child: Tab(
                                  child: Text(
                                    "Todos (${provedor.comandas.fold(0, (previousValue, element) => previousValue + (element.comandas?.length ?? 0))})",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              ...provedor.comandas.map(
                                (e) => SizedBox(
                                  height: 40,
                                  child: Tab(
                                    child: Text(
                                      "${e.titulo} (${e.comandas!.length})",
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10, right: 10, top: 15),
                                child: SizedBox(
                                  height: 40,
                                  child: TextField(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderSide: BorderSide(color: Colors.grey[700]!),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      hintText: 'Pesquisa',
                                      prefixIcon: const Icon(Icons.search),
                                      contentPadding: const EdgeInsets.all(0),
                                    ),
                                    onChanged: (textoPesquisa) async {
                                      if (_debounce?.isActive ?? false) _debounce!.cancel();

                                      _debounce = Timer(const Duration(milliseconds: 500), () {
                                        if (textoPesquisa.isNotEmpty) {
                                          if (debounce?.isActive ?? false) {
                                            debounce!.cancel();
                                          }

                                          debounce = Timer(const Duration(milliseconds: 200), () async {
                                            provedor.listarComandas(textoPesquisa);
                                          });
                                        } else {
                                          provedor.listarComandas('');
                                        }
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.only(right: 15, top: 15),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey[700]!),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.qr_code_scanner_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              RefreshIndicator(
                                onRefresh: () async {
                                  listarComandas();
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
                                        itemCount: provedor.comandas.length,
                                        itemBuilder: (context, index) {
                                          final item = provedor.comandas[index];

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.titulo, style: const TextStyle(fontSize: 16)),
                                              ListView.builder(
                                                physics: const NeverScrollableScrollPhysics(),
                                                shrinkWrap: true,
                                                scrollDirection: Axis.vertical,
                                                itemCount: item.comandas?.length ?? 0,
                                                padding: const EdgeInsets.only(top: 5, bottom: 10),
                                                itemBuilder: (_, index) {
                                                  var itemComanda = item.comandas![index];

                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 10),
                                                    child: CardComanda(itemComanda: itemComanda),
                                                  );
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
                              RefreshIndicator(
                                onRefresh: () async {
                                  listarComandas();
                                },
                                child: Column(
                                  children: [
                                    ...provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty).map((e) {
                                      return Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
                                          shrinkWrap: true,
                                          itemCount:
                                              provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty).length,
                                          itemBuilder: (context, index) {
                                            final item = provedor.comandas
                                                .where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty)
                                                .toList()[index];

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(item.titulo, style: const TextStyle(fontSize: 16)),
                                                ListView.builder(
                                                  physics: const NeverScrollableScrollPhysics(),
                                                  shrinkWrap: true,
                                                  scrollDirection: Axis.vertical,
                                                  itemCount: item.comandas!.length,
                                                  padding: const EdgeInsets.only(top: 5, bottom: 10),
                                                  itemBuilder: (_, index) {
                                                    var itemComanda = item.comandas![index];

                                                    return Padding(
                                                      padding: const EdgeInsets.only(bottom: 10),
                                                      child: CardComanda(itemComanda: itemComanda),
                                                    );
                                                  },
                                                ),
                                              ],
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                              RefreshIndicator(
                                onRefresh: () async {
                                  listarComandas();
                                },
                                child: Column(
                                  children: [
                                    ...provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == false).isNotEmpty).map((e) {
                                      return Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
                                          shrinkWrap: true,
                                          itemCount: provedor.comandas
                                              .where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == false).isNotEmpty)
                                              .toList()
                                              .length,
                                          itemBuilder: (context, index) {
                                            final item = provedor.comandas
                                                .where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == false).isNotEmpty)
                                                .toList()[index];

                                            return ListView.builder(
                                              physics: const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              // gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                              //   crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                                              //   mainAxisExtent: 100,
                                              //   mainAxisSpacing: 2,
                                              //   crossAxisSpacing: 2,
                                              // ),
                                              scrollDirection: Axis.vertical,
                                              itemCount: item.comandas!.length,
                                              padding: const EdgeInsets.only(top: 5, bottom: 10),
                                              itemBuilder: (_, index) {
                                                var itemComanda = item.comandas![index];

                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: CardComanda(itemComanda: itemComanda),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
