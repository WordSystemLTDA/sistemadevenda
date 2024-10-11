import 'dart:async';

import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

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

  Timer? _tickerTempoLancado;
  // antiga animação card produto
  StreamController<String> tempoLancadoController = StreamController<String>.broadcast();

  void _updateTimer() {
    if (widget.item.dataAbertura != null) {
      final duration = DateTime.now().difference(DateTime.parse(widget.item.dataAbertura!));
      final newDuration = ConfigSistema.formatarHora(duration);

      tempoLancadoController.add(newDuration);
    }
  }

  @override
  void initState() {
    super.initState();

    // _timeStreamController = StreamController<String>();
    // _timeStream = _timeStreamController.stream;

    if (widget.item.mesaOcupada) {
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
          gradient: widget.item.mesaOcupada
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
            if (!widget.item.mesaOcupada) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaComandaDesocupada(id: widget.item.id, idComandaPedido: widget.item.idComandaPedido, nome: widget.item.nome),
                ),
              );
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaDetalhesPedido(
                    idComandaPedido: widget.item.idComandaPedido,
                    idComanda: widget.item.id,
                    tipo: TipoCardapio.mesa,
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
                      widget.item.nome,
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
              if (widget.item.mesaOcupada) ...[
                Row(
                  children: [
                    const SizedBox(width: 15),
                    SizedBox(
                      width: 150,
                      child: Text(
                        widget.item.nomeCliente != null && widget.item.nomeCliente!.isNotEmpty ? widget.item.nomeCliente! : 'Sem Cliente',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: widget.item.mesaOcupada ? Colors.black : Colors.grey[600],
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
                      Text(double.parse(widget.item.valor ?? '0').obterReal(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
