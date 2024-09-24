import 'dart:async';

import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/widgets/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/comandas/modelos/comanda_model.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class CardComanda extends StatefulWidget {
  final ComandaModel itemComanda;
  const CardComanda({super.key, required this.itemComanda});

  @override
  State<CardComanda> createState() => _CardComandaState();
}

class _CardComandaState extends State<CardComanda> {
  // late StreamController<String> _timeStreamController;
  // late Stream<String> _timeStream;

  // final Temporizador temporizador = Temporizador();

  Timer? _tickerTempoLancado;
  // antiga animação card produto
  StreamController<String> tempoLancadoController = StreamController<String>.broadcast();

  void _updateTimer() {
    if (widget.itemComanda.dataAbertura != null) {
      final duration = DateTime.now().difference(DateTime.parse(widget.itemComanda.dataAbertura!));
      final newDuration = ConfigSistema.formatarHora(duration);

      tempoLancadoController.add(newDuration);
    }
  }

  @override
  void initState() {
    super.initState();

    // _timeStreamController = StreamController<String>();
    // _timeStream = _timeStreamController.stream;

    if (widget.itemComanda.comandaOcupada) {
      _updateTimer();
      _tickerTempoLancado ??= Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
    }
  }

  @override
  void dispose() {
    if (_tickerTempoLancado != null) {
      _tickerTempoLancado!.cancel();
      tempoLancadoController.close();
    }
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
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaComandaDesocupada(id: widget.itemComanda.id, idComandaPedido: widget.itemComanda.idComandaPedido, nome: widget.itemComanda.nome),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaDetalhesPedido(
                    idComandaPedido: widget.itemComanda.idComandaPedido,
                    idComanda: widget.itemComanda.id,
                  ),
                ),
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
                      widget.itemComanda.nome,
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
                    SizedBox(
                      width: 170,
                      child: Text(
                        widget.itemComanda.nomeCliente != null && widget.itemComanda.nomeCliente!.isNotEmpty ? widget.itemComanda.nomeCliente! : 'Sem Cliente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.itemComanda.comandaOcupada ? Colors.black : Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Padding(
                  padding: const EdgeInsets.only(left: 15.0, top: 1, right: 15),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      StreamBuilder<String>(
                        stream: tempoLancadoController.stream,
                        initialData: 'Carregando',
                        builder: (context, snapshot) {
                          return Text(snapshot.data!, style: const TextStyle(fontSize: 12));
                        },
                      ),
                      Text(double.parse(widget.itemComanda.valor ?? '0').obterReal(), style: const TextStyle(color: Colors.white))
                    ],
                  ),
                ),
                if (widget.itemComanda.nomeMesa != null && widget.itemComanda.nomeMesa!.isNotEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const SizedBox(width: 15),
                          Text(
                            widget.itemComanda.nomeMesa != null && widget.itemComanda.nomeMesa!.isNotEmpty ? 'Mesa: ${widget.itemComanda.nomeMesa!.split(' ')[1]}' : '',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: widget.itemComanda.comandaOcupada ? Colors.black : Colors.grey[600],
                            ),
                          ),
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
