import 'dart:async';

import 'package:app/src/features/comandas/interactor/models/comanda_model.dart';
import 'package:app/src/features/comandas/ui/comanda_desocupada_page.dart';
import 'package:app/src/shared/utils/temporizador.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardComanda extends StatefulWidget {
  final ComandaModel itemComanda;
  const CardComanda({super.key, required this.itemComanda});

  @override
  State<CardComanda> createState() => _CardComandaState();
}

class _CardComandaState extends State<CardComanda> {
  late StreamController<String> _timeStreamController;
  late Stream<String> _timeStream;

  final Temporizador temporizador = Temporizador();

  void _updateTime() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _timeStreamController.add(temporizador.main(
          widget.itemComanda.horaAbertura,
          widget.itemComanda.dataAbertura,
        ));
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();

    _timeStreamController = StreamController<String>();
    _timeStream = _timeStreamController.stream;

    if (widget.itemComanda.comandaOcupada) {
      _updateTime();
    }
  }

  @override
  void dispose() {
    _timeStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: widget.itemComanda.comandaOcupada
              ? LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.inversePrimary,
                    Theme.of(context).colorScheme.primary,
                  ],
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: InkWell(
          onTap: () {
            if (!widget.itemComanda.comandaOcupada) {
              Modular.to.push(MaterialPageRoute(
                  builder: (context) => ComandaDesocupadaPage(
                        id: widget.itemComanda.id,
                        nome: widget.itemComanda.nome,
                      )));
            } else {
              showDialog(
                context: context,
                builder: (context) {
                  return SizedBox(
                    child: Dialog(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Card(
                                  child: SizedBox(
                                    width: (MediaQuery.of(context).size.width - 120) / 2,
                                    height: (MediaQuery.of(context).size.width - 120) / 2,
                                    child: InkWell(
                                      onTap: () {
                                        Modular.to.pushNamed('/cardapio/Comanda/${widget.itemComanda.id}/0');
                                        Navigator.pop(context);
                                      },
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: const Center(child: Icon(Icons.add)),
                                    ),
                                  ),
                                ),
                                Card(
                                  child: SizedBox(
                                    width: (MediaQuery.of(context).size.width - 120) / 2,
                                    height: (MediaQuery.of(context).size.width - 120) / 2,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: const Center(child: Icon(Icons.production_quantity_limits)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Card(
                                  child: SizedBox(
                                    width: (MediaQuery.of(context).size.width - 120) / 2,
                                    height: (MediaQuery.of(context).size.width - 120) / 2,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: const Center(child: Icon(Icons.print)),
                                    ),
                                  ),
                                ),
                                Card(
                                  child: SizedBox(
                                    width: (MediaQuery.of(context).size.width - 120) / 2,
                                    height: (MediaQuery.of(context).size.width - 120) / 2,
                                    child: InkWell(
                                      onTap: () {
                                        Navigator.pop(context);
                                      },
                                      borderRadius: const BorderRadius.all(Radius.circular(10)),
                                      child: const Center(child: Icon(Icons.edit)),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            }
          },
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  const SizedBox(width: 15),
                  const Icon(Icons.topic_outlined, size: 30),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: MediaQuery.of(context).size.width / 2 - 70,
                    child: Text(
                      'Comanda: ${widget.itemComanda.nome}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        overflow: TextOverflow.ellipsis,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              if (widget.itemComanda.comandaOcupada) ...[
                Row(
                  children: [
                    const SizedBox(width: 15),
                    Text(
                      widget.itemComanda.nomeCliente.isNotEmpty ? widget.itemComanda.nomeCliente : 'Diversos',
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.itemComanda.comandaOcupada ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const SizedBox(width: 15),
                        Text(
                          widget.itemComanda.nomeMesa.isNotEmpty ? 'Mesa: ${widget.itemComanda.nomeMesa.split(' ')[1]}' : '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.itemComanda.comandaOcupada ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        StreamBuilder<String>(
                          stream: _timeStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              String formattedTime = snapshot.data!;

                              return Row(
                                children: [
                                  const Icon(Icons.watch_later_outlined, size: 14, color: Colors.black),
                                  const SizedBox(width: 5),
                                  Text(
                                    formattedTime,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              );
                            } else {
                              return const Text(
                                'Carregando...',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 14,
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(width: 15),
                      ],
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
