import 'dart:async';

import 'package:app/src/features/mesas/interactor/models/mesa_modelo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardMesaOcupada extends StatefulWidget {
  final MesaModelo item;
  const CardMesaOcupada({super.key, required this.item});

  @override
  State<CardMesaOcupada> createState() => _CardMesaOcupadaState();
}

class _CardMesaOcupadaState extends State<CardMesaOcupada> {
  // late StreamController<String> _timeStreamController;
  // late Stream<String> _timeStream;

  // final Temporizador temporizador = Temporizador();

  void _updateTime() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        // _timeStreamController.add(temporizador.main(
        //   widget.item.horaAbertura,
        //   widget.item.dataAbertura,
        // ));
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();

    // _timeStreamController = StreamController<String>();
    // _timeStream = _timeStreamController.stream;

    if (widget.item.mesaOcupada) {
      _updateTime();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      // color: Theme.of(context).colorScheme.inversePrimary,
      margin: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.inversePrimary,
              Theme.of(context).colorScheme.primary,
            ],
            end: Alignment.bottomRight,
          ),
        ),
        child: InkWell(
          onTap: () {
            Modular.to.pushNamed('/cardapio/Mesa/0/${widget.item.id}');
          },
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(width: 15),
                  const Icon(Icons.table_bar_outlined),
                  const SizedBox(width: 10),
                  Text(widget.item.nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              Row(
                children: [
                  const SizedBox(width: 15),
                  Text(
                    widget.item.nomeCliente.isNotEmpty ? widget.item.nomeCliente : 'Diversos',
                    style: const TextStyle(fontSize: 14, color: Colors.black),
                  ),
                ],
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // StreamBuilder<String>(
                  //   stream: _timeStream,
                  //   builder: (context, snapshot) {
                  //     if (snapshot.hasData) {
                  //       String formattedTime = snapshot.data!;

                  //       return Row(
                  //         children: [
                  //           const Icon(Icons.watch_later_outlined, size: 14, color: Colors.black),
                  //           const SizedBox(width: 5),
                  //           Text(
                  //             formattedTime,
                  //             style: const TextStyle(
                  //               color: Colors.black,
                  //               fontSize: 14,
                  //             ),
                  //           ),
                  //         ],
                  //       );
                  //     } else {
                  //       return const Text(
                  //         'Carregando...',
                  //         style: TextStyle(
                  //           color: Colors.black,
                  //           fontSize: 14,
                  //         ),
                  //       );
                  //     }
                  //   },
                  // ),
                  SizedBox(width: 15),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
