import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/widgets/qrcode_scanner_com_overlay.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/modal_digitar_codigo.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_lista_mesas.dart';
import 'package:app/src/modulos/mesas/paginas/widgets/card_mesa_ocupada.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PaginaMesas extends StatefulWidget {
  const PaginaMesas({super.key});

  @override
  State<PaginaMesas> createState() => _PaginaMesasState();
}

class _PaginaMesasState extends State<PaginaMesas> {
  ServicoConfigBigchef servicoConfigBigchef = Modular.get<ServicoConfigBigchef>();
  final MobileScannerController controller = MobileScannerController();
  UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  TextEditingController pesquisaController = TextEditingController();

  Timer? debounce;
  Timer? _debounce;

  final ProvedorMesas provedor = Modular.get<ProvedorMesas>();
  bool isLoading = true;
  Timer? _timer;
  bool nfcDisponivel = true;
  String opcaoFiltro = 'Ocupadas';
  ModeloConfigBigchef? configBigchef;

  @override
  void initState() {
    super.initState();
    listarMesas();
  }

  void listarMesas() async {
    configBigchef = await servicoConfigBigchef.listar();
    nfcDisponivel = await FlutterNfcKit.nfcAvailability == NFCAvailability.available;

    setState(() => isLoading = true);
    await provedor.listarMesas('');
    setState(() => isLoading = false);

    if (configBigchef?.autenticarcomtag == 'Sim' && await FlutterNfcKit.nfcAvailability == NFCAvailability.available) {
      await nfc();
    }
  }

  Future<void> nfc() async {
    FlutterNfcKit.finish();

    try {
      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiplas TAGS Encontradas!",
        iosAlertMessage: "Escaneie a sua TAG",
        readIso14443A: true,
      );

      if (tag.type == NFCTagType.mifare_ultralight) {
        var ndef = await FlutterNfcKit.readNDEFRecords();

        var payload = ndef.first.toString();
        var dataText = payload.indexOf('text=');
        var codigo = payload.substring(dataText + 5);

        final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

        await servicoCardapio.listarIdCodigoQrcode(TipoCardapio.mesa, codigo).then((value) {
          if (value.sucesso == false) {
            FlutterNfcKit.finish(iosErrorMessage: 'Essa mesa não existe.');
            return;
          } else {
            FlutterNfcKit.finish();
          }

          if (value.ocupado == true) {
            if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '1') {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaginaDetalhesPedido(
                      idComandaPedido: value.idComandaPedido,
                      idMesa: value.id,
                      tipo: TipoCardapio.mesa,
                    ),
                  ),
                );
              }
            } else if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '2') {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaginaDetalhesPedido(
                      idComandaPedido: value.idComandaPedido,
                      idMesa: value.id,
                      tipo: TipoCardapio.mesa,
                      abrirModalFecharDireto: true,
                    ),
                  ),
                );
              }
            } else if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '3') {
              if (value.fechamento == true) {
                if (mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PaginaDetalhesPedido(
                        idComandaPedido: value.idComandaPedido,
                        idMesa: value.id,
                        tipo: TipoCardapio.mesa,
                      ),
                    ),
                  );
                }
                return;
              }

              if (mounted) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return PaginaCardapio(
                      tipo: TipoCardapio.comanda,
                      idComanda: value.id,
                      idMesa: '0',
                      idCliente: value.idCliente,
                      id: value.idComandaPedido,
                    );
                  },
                ));
              }
            }
          } else {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaComandaDesocupada(
                    id: value.id,
                    nome: value.nome,
                    tipo: TipoCardapio.mesa,
                  ),
                ),
              );
            }
          }
        });
      } else {
        FlutterNfcKit.finish(iosErrorMessage: 'Tipo de TAG não reconhecido: ${tag.type.name}');
        return;
      }
    } on PlatformException catch (e) {
      FlutterNfcKit.finish(iosErrorMessage: e.details);
    }
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
        title: const Text('Mesas'),
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
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PaginaListaMesas()));
                },
                child: const Row(
                  children: [
                    SizedBox(width: 20),
                    Text('Mesas'),
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
            onRefresh: () async => listarMesas(),
            child: Visibility(
              visible: isLoading == false,
              replacement: const Center(child: CircularProgressIndicator()),
              child: Stack(
                children: [
                  DefaultTabController(
                    // length: provedor.mesas.isNotEmpty ? (provedor.mesas.length + 1) : 1,
                    length: (provedor.mesas.isNotEmpty ? (provedor.mesas.length + 1) : 1) -
                        (provedor.mesas
                                .where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == true && element.titulo == 'em Fechamento').isNotEmpty)
                                .isNotEmpty
                            ? 1
                            : 0),
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
                                    "Todos (${provedor.mesas.fold(0, (previousValue, element) => previousValue + (element.mesas?.length ?? 0))})",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 40,
                                child: Tab(
                                  child: Text(
                                    "Ocupadas (${provedor.mesas.where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == true).isNotEmpty).fold(0, (previousValue, element) => previousValue + (element.mesas?.length ?? 0))})",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 40,
                                child: Tab(
                                  child: Text(
                                    "Livres (${provedor.mesas.where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == false).isNotEmpty).fold(0, (previousValue, element) => previousValue + (element.mesas?.length ?? 0))})",
                                    style: const TextStyle(fontSize: 14),
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
                                    controller: pesquisaController,
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
                                      setState(() {});
                                      // if (_debounce?.isActive ?? false) _debounce!.cancel();

                                      // _debounce = Timer(const Duration(milliseconds: 500), () {
                                      //   if (textoPesquisa.isNotEmpty) {
                                      //     if (debounce?.isActive ?? false) {
                                      //       debounce!.cancel();
                                      //     }

                                      //     debounce = Timer(const Duration(milliseconds: 200), () async {
                                      //       provedor.listarMesas(textoPesquisa);
                                      //     });
                                      //   } else {
                                      //     provedor.listarMesas('');
                                      //   }
                                      // });
                                    },
                                  ),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                showModalBottomSheet(
                                  context: context,
                                  isScrollControlled: true,
                                  backgroundColor: Colors.transparent,
                                  showDragHandle: false,
                                  builder: (context) {
                                    return GestureDetector(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      child: const ModalDigitarCodigo(
                                        tipo: TipoCardapio.mesa,
                                      ),
                                    );
                                  },
                                );
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
                                  child: const Icon(Icons.add_task),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(
                                  builder: (context) {
                                    return const BarcodeScannerWithOverlay(tipo: TipoCardapio.mesa);
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
                            if (configBigchef?.autenticarcomtag == 'Sim' && nfcDisponivel)
                              GestureDetector(
                                onTap: () async {
                                  await nfc();
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
                                    child: const Icon(Icons.nfc_outlined),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              // 1 TAB
                              RefreshIndicator(
                                onRefresh: () async {
                                  listarMesas();
                                },
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
                                        itemCount: provedor.mesas.length,
                                        itemBuilder: (context, index) {
                                          final item = provedor.mesas[index];

                                          return Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(item.titulo, style: const TextStyle(fontSize: 16)),
                                              ListView.builder(
                                                physics: const NeverScrollableScrollPhysics(),
                                                shrinkWrap: true,
                                                scrollDirection: Axis.vertical,
                                                itemCount: (item.mesas ?? [])
                                                    .where((element) =>
                                                        (element.nomeCliente ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                        (element.obs ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                        (element.nome).toLowerCase().contains(pesquisaController.text))
                                                    .length,
                                                padding: const EdgeInsets.only(top: 5, bottom: 10),
                                                itemBuilder: (_, index) {
                                                  var itemMesa = (item.mesas ?? [])
                                                      .where((element) =>
                                                          (element.nomeCliente ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                          (element.obs ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                          (element.nome).toLowerCase().contains(pesquisaController.text))
                                                      .toList()[index];

                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 10),
                                                    child: CardMesaOcupada(item: itemMesa),
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
                              // 2 TAB
                              RefreshIndicator(
                                onRefresh: () async {
                                  listarMesas();
                                },
                                child: Column(
                                  children: [
                                    ...provedor.mesas.where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == true).isNotEmpty).map((e) {
                                      return Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
                                          shrinkWrap: true,
                                          itemCount: provedor.mesas.where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == true).isNotEmpty).length,
                                          itemBuilder: (context, index) {
                                            final item = provedor.mesas
                                                .where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == true).isNotEmpty)
                                                .toList()[index];

                                            return ListView.builder(
                                              physics: const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              scrollDirection: Axis.vertical,
                                              itemCount: item.mesas!.length,
                                              padding: const EdgeInsets.only(top: 5, bottom: 10),
                                              itemBuilder: (_, index) {
                                                var itemMesa = item.mesas![index];

                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: CardMesaOcupada(item: itemMesa),
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
                              // 3 TAB
                              RefreshIndicator(
                                onRefresh: () async {
                                  listarMesas();
                                },
                                child: Column(
                                  children: [
                                    ...provedor.mesas.where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == false).isNotEmpty).map((e) {
                                      return Expanded(
                                        child: ListView.builder(
                                          padding: const EdgeInsets.only(right: 10, left: 10, top: 10),
                                          shrinkWrap: true,
                                          itemCount: provedor.mesas
                                              .where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == false).isNotEmpty)
                                              .toList()
                                              .length,
                                          itemBuilder: (context, index) {
                                            final item = provedor.mesas
                                                .where((element) => (element.mesas ?? []).where((element2) => element2.mesaOcupada == false).isNotEmpty)
                                                .toList()[index];

                                            return ListView.builder(
                                              physics: const NeverScrollableScrollPhysics(),
                                              shrinkWrap: true,
                                              scrollDirection: Axis.vertical,
                                              itemCount: item.mesas!.length,
                                              padding: const EdgeInsets.only(top: 5, bottom: 10),
                                              itemBuilder: (_, index) {
                                                var itemMesa = item.mesas![index];

                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 10),
                                                  child: CardMesaOcupada(item: itemMesa),
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
