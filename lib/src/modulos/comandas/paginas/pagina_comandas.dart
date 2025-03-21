import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/widgets/qrcode_scanner_com_overlay.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/modal_digitar_codigo.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  TextEditingController pesquisaController = TextEditingController();

  Timer? debounce;
  Timer? _debounce;

  final ProvedorComanda provedor = Modular.get<ProvedorComanda>();
  bool isLoading = true;
  Timer? _timer;
  String opcaoFiltro = 'Ocupadas';
  bool nfcDisponivel = true;
  ModeloConfigBigchef? configBigchef;

  @override
  void initState() {
    super.initState();
    listarComandas();
  }

  void listarComandas() async {
    configBigchef = await servicoConfigBigchef.listar();
    nfcDisponivel = await FlutterNfcKit.nfcAvailability == NFCAvailability.available;

    setState(() => isLoading = true);
    await provedor.listarComandas('');
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
        if (ndef.isEmpty) {
          FlutterNfcKit.finish(iosErrorMessage: 'Essa TAG não tem código Registrado.');
          return;
        }

        var payload = ndef.first.toString();
        var dataText = payload.indexOf('text=');
        var codigo = payload.substring(dataText + 5);

        final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

        await servicoCardapio.listarIdCodigoQrcode(TipoCardapio.comanda, codigo).then((value) {
          if (value.sucesso == false) {
            FlutterNfcKit.finish(iosErrorMessage: 'Essa comanda não existe.');
            return;
          } else {
            FlutterNfcKit.finish();
          }

          if (value.ocupado == true) {
            if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '1') {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaginaDetalhesPedido(
                      idComandaPedido: value.idComandaPedido,
                      idComanda: value.id,
                      tipo: TipoCardapio.comanda,
                    ),
                  ),
                );
              }
            } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '2') {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaginaDetalhesPedido(
                      idComandaPedido: value.idComandaPedido,
                      idComanda: value.id,
                      tipo: TipoCardapio.comanda,
                      abrirModalFecharDireto: true,
                    ),
                  ),
                );
              }
            } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '3') {
              if (value.fechamento == true) {
                if (mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PaginaDetalhesPedido(
                        idComandaPedido: value.idComandaPedido,
                        idComanda: value.id,
                        tipo: TipoCardapio.comanda,
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
                    tipo: TipoCardapio.comanda,
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
    // FlutterNfcKit.finish();

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
                    length: (provedor.comandas.isNotEmpty ? (provedor.comandas.length + 1) : 1) -
                        (provedor.comandas
                                .where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true && element.titulo == 'em Fechamento').isNotEmpty)
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
                                    "Todos (${provedor.comandas.fold(0, (previousValue, element) => previousValue + (element.comandas?.length ?? 0))})",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 40,
                                child: Tab(
                                  child: Text(
                                    "Ocupadas (${provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty).fold(0, (previousValue, element) => previousValue + (element.comandas?.length ?? 0))})",
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 40,
                                child: Tab(
                                  child: Text(
                                    "Livres (${provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == false).isNotEmpty).fold(0, (previousValue, element) => previousValue + (element.comandas?.length ?? 0))})",
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
                                      //       provedor.listarComandas(textoPesquisa);
                                      //     });
                                      //   } else {
                                      //     provedor.listarComandas('');
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
                                        tipo: TipoCardapio.comanda,
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
                                                itemCount: (item.comandas ?? [])
                                                    .where((element) =>
                                                        (element.nomeCliente ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                        (element.obs ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                        (element.nome).toLowerCase().contains(pesquisaController.text))
                                                    .length,
                                                padding: const EdgeInsets.only(top: 5, bottom: 10),
                                                itemBuilder: (_, index) {
                                                  var itemComanda = (item.comandas ?? [])
                                                      .where((element) =>
                                                          (element.nomeCliente ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                          (element.obs ?? '').toLowerCase().contains(pesquisaController.text) ||
                                                          (element.nome).toLowerCase().contains(pesquisaController.text))
                                                      .toList()[index];

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
                              // if (provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true).isNotEmpty).isNotEmpty)
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
                              // if (provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == false).isNotEmpty).isNotEmpty)
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
