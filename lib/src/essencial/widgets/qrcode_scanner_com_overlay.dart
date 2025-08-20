import 'package:app/src/essencial/widgets/scanner_error_widget.dart';
import 'package:app/src/essencial/widgets/scanner_overlay.dart';
import 'package:app/src/essencial/widgets/toggle_flash_button.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/paginas/widgets/card_mesa_ocupada.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class BarcodeScannerWithOverlay extends StatefulWidget {
  final TipoCardapio tipo;
  const BarcodeScannerWithOverlay({super.key, required this.tipo});

  @override
  State<BarcodeScannerWithOverlay> createState() => _BarcodeScannerWithOverlayState();
}

class _BarcodeScannerWithOverlayState extends State<BarcodeScannerWithOverlay> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.all],
  );

  bool scanear = true;

  @override
  Widget build(BuildContext context) {
    final scanWindow = Rect.fromCenter(
      center: MediaQuery.sizeOf(context).center(const Offset(0, 0)),
      width: 250,
      height: 250,
    );

    return Scaffold(
      // backgroundColor: Colors.black,
      // appBar: AppBar(
      //   title: const Text('Aponte a câmera para ler o Qr Code'),
      // ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: MobileScanner(
              fit: BoxFit.cover,
              controller: controller,
              scanWindow: scanWindow,
              onDetect: (barcodes) async {
                if (scanear == false) return;

                controller.stop();
                // print(barcodes);
                setState(() {
                  scanear = false;
                });

                if (barcodes.barcodes.first.rawValue != null) {
                  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

                  await servicoCardapio.listarIdCodigoQrcode(widget.tipo, barcodes.barcodes.first.rawValue).then((value) {
                    if (value.ocupado) {
                      if (context.mounted) {
                        Navigator.of(context)
                            .push(
                          MaterialPageRoute(
                            builder: (context) => PaginaDetalhesPedido(
                              idComandaPedido: '0',
                              idComanda: '0',
                              codigoQrcode: barcodes.barcodes.first.rawValue,
                              tipo: widget.tipo,
                            ),
                          ),
                        )
                            .then((value) {
                          controller.start();
                          setState(() {
                            scanear = true;
                          });
                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        });
                      }
                    } else {
                      if (context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaginaComandaDesocupada(
                              id: value.id,
                              nome: '',
                              tipo: widget.tipo,
                            ),
                          ),
                        );
                      }
                    }
                  });
                }
              },
              errorBuilder: (context, error) {
                return ScannerErrorWidget(error: error);
              },
              // overlayBuilder: (context, constraints) {
              //   return Padding(
              //     padding: const EdgeInsets.all(16.0),
              //     child: Align(
              //       alignment: Alignment.bottomCenter,
              //       child: ScannedBarcodeLabel(barcodes: controller.barcodes),
              //     ),
              //   );
              // },
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, child) {
              if (!value.isInitialized || !value.isRunning || value.error != null) {
                return const SizedBox();
              }

              return CustomPaint(
                painter: ScannerOverlay(scanWindow: scanWindow),
              );
            },
          ),
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 15, top: 50),
              child: IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.close),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, state, _) {
              return Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 100),
                  child: state.isRunning
                      ? const Text('Aponte a câmera para ler o Qr Code', style: TextStyle(fontWeight: FontWeight.bold))
                      : const Text('Câmera pausada', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              );
            },
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, _) {
                      if (state.isRunning == false) return const SizedBox();

                      return Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ToggleFlashlightButton(controller: controller),
                            const Text('Flash'),
                          ],
                        ),
                      );
                    },
                  ),
                  ValueListenableBuilder(
                    valueListenable: controller,
                    builder: (context, state, _) {
                      return GestureDetector(
                        onTap: () {
                          if (state.isRunning) {
                            controller.stop();
                          } else {
                            controller.start();
                          }
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(state.isRunning ? Icons.pause : Icons.not_started),
                              const SizedBox(height: 10),
                              Text(state.isRunning ? 'Pausar' : 'Voltar'),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  SearchAnchor(
                    builder: (BuildContext context, SearchController controllerSearch) {
                      return GestureDetector(
                        onTap: () {
                          controller.stop();
                          controllerSearch.openView();
                        },
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ToggleFlashlightButton(controller: controller),
                              Icon(Icons.keyboard_outlined, size: 32),
                              SizedBox(height: 10),
                              Text('Digitar'),
                            ],
                          ),
                        ),
                      );
                    },
                    suggestionsBuilder: (BuildContext context, SearchController controllerSearch) async {
                      final keyword = controllerSearch.value.text;
                      final ServicoComandas servicoComandas = Modular.get<ServicoComandas>();
                      final ServicoMesas servicoMesas = Modular.get<ServicoMesas>();

                      var resMesas = await servicoMesas.listar(keyword);
                      var resComandas = await servicoComandas.listar(keyword);

                      return [
                        if (widget.tipo == TipoCardapio.comanda) ...[
                          ...resComandas.map(
                            (item) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
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
                              ),
                            ),
                          ),
                        ] else if (widget.tipo == TipoCardapio.mesa) ...[
                          ...resMesas.map(
                            (item) => Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.titulo, style: const TextStyle(fontSize: 16)),
                                  ListView.builder(
                                    physics: const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    scrollDirection: Axis.vertical,
                                    itemCount: item.mesas?.length ?? 0,
                                    padding: const EdgeInsets.only(top: 5, bottom: 10),
                                    itemBuilder: (_, index) {
                                      var itemMesa = item.mesas![index];

                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 10),
                                        child: CardMesaOcupada(item: itemMesa),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ];
                    },
                  ),

                  // SwitchCameraButton(controller: controller),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Future<void> dispose() async {
    super.dispose();
    await controller.dispose();
  }
}
