import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/widgets/qrcode_scanner_com_overlay.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PaginaComandas extends StatefulWidget {
  const PaginaComandas({super.key});

  @override
  State<PaginaComandas> createState() => _PaginaComandasState();
}

class _PaginaComandasState extends State<PaginaComandas> {
  ServicoConfigBigchef servicoConfigBigchef = Modular.get<ServicoConfigBigchef>();
  final MobileScannerController controller = MobileScannerController();

  Timer? debounce;
  Timer? _debounce;

  final ProvedorComanda provedor = Modular.get<ProvedorComanda>();
  bool isLoading = false;
  Timer? _timer;
  String opcaoFiltro = 'Ocupadas';
  ModeloConfigBigchef? configBigchef;

  void listarComandas() async {
    configBigchef = await servicoConfigBigchef.listar();
    setState(() => isLoading = !isLoading);
    await provedor.listarComandas('');

    if (configBigchef?.autenticarcomtag == 'Sim') {
      nfc();
    }
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();
    listarComandas();
  }

  void nfc() async {
    FlutterNfcKit.finish();

    try {
      var tag =
          await FlutterNfcKit.poll(timeout: const Duration(seconds: 10), iosMultipleTagMessage: "Multiple tags found!", iosAlertMessage: "Scan your tag", readIso14443A: true);

      print(jsonEncode(tag));

      if (tag.type == NFCTagType.mifare_ultralight) {
        // var a = await FlutterNfcKit.readNDEFRawRecords();
        var ndef = await FlutterNfcKit.readNDEFRecords();
        // print(a);
        // print(b);

        var payload = ndef.first.toString();
        var dataText = payload.indexOf('text=');
        var codigo = payload.substring(dataText + 5);

        print(codigo);

        final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

        print(codigo);

        await servicoCardapio.listarIdCodigoQrcode(TipoCardapio.comanda, codigo).then((value) {
          // print(jsonDecode(value.toString()));

          if (value.sucesso == false) {
            // if (mounted) {
            //   ScaffoldMessenger.of(context).removeCurrentSnackBar();
            //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            //     content: Text('Não existe comanda'),
            //     backgroundColor: Colors.red,
            //   ));
            // }

            FlutterNfcKit.finish(iosErrorMessage: 'Não existe comanda');
            return;
          } else {
            // FlutterNfcKit.
            FlutterNfcKit.finish();
          }

          if (value.ocupado == true) {
            if (mounted) {
              Navigator.of(context)
                  .push(
                MaterialPageRoute(
                  builder: (context) => PaginaDetalhesPedido(
                    idComandaPedido: value.idComandaPedido,
                    idComanda: value.id,
                    tipo: TipoCardapio.comanda,
                  ),
                ),
              )
                  .then((value) {
                if (mounted) {
                  Navigator.pop(context);
                }
              });
            }
          } else {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaComandaDesocupada(
                    id: value.id,
                    nome: value.nome,
                    tipo: TipoCardapio.comanda,
                  ),
                ),
              );
            }
          }
        });

        // if (mounted) {
        //   Navigator.of(context).push(
        //     MaterialPageRoute(
        //       builder: (context) => PaginaDetalhesPedido(
        //         idComandaPedido: '0',
        //         idComanda: '0',
        //         codigoQrcode: codigo,
        //         tipo: TipoCardapio.comanda,
        //       ),
        //     ),
        //   );
        // }
        // Uint8List.fromList(stringPdf.codeUnits);
        // print(ndef.first.);
      }

      if (tag.type == NFCTagType.iso15693) {
        await FlutterNfcKit.writeBlock(
            1, // index
            [0xde, 0xad, 0xbe, 0xff], // data
            iso15693Flags: Iso15693RequestFlags(), // optional flags for ISO 15693
            iso15693ExtendedMode: false // use extended mode for ISO 15693
            );
      }

      if (tag.type == NFCTagType.iso15693) {
        await FlutterNfcKit.writeBlock(
            1, // index
            [0xde, 0xad, 0xbe, 0xff], // data
            iso15693Flags: Iso15693RequestFlags(), // optional flags for ISO 15693
            iso15693ExtendedMode: false // use extended mode for ISO 15693
            );
      }

      if (tag.type == NFCTagType.iso7816) {
        var result = await FlutterNfcKit.transceive("04CAA893C12A81"); // timeout is still Android-only, persist until next change
        print(result);
      }

      if (tag.type == NFCTagType.mifare_classic) {
        try {
          await FlutterNfcKit.authenticateSector(0, keyA: "04CAA893C12A81");
          var data = await FlutterNfcKit.readSector(0); // read one sector, or
          // var data = await FlutterNfcKit.readBlock(0); // read one block

          print(data);
        } catch (e) {
          print(e);
        }
      }
    } catch (e) {
      FlutterNfcKit.finish(iosErrorMessage: 'Não existe comanda');
      print(e);
    }
    // print(jsonEncode(tag));
  }

  @override
  void dispose() {
    FlutterNfcKit.finish();
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
                                      "${e.titulo} (${e.comandas?.length ?? 0})",
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
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) {
                                    return const BarcodeScannerWithOverlay(tipo: TipoCardapio.comanda);
                                  },
                                ));
                              },
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
                              if (provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty).isNotEmpty)
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
                                            itemCount: provedor.comandas
                                                .where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty)
                                                .length,
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
                              if (provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == false).isNotEmpty).isNotEmpty)
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
