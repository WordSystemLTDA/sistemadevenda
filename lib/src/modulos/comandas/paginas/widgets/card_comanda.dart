import 'package:app/src/essencial/widgets/pagina_detalhes_pedidos.dart';
import 'package:app/src/essencial/widgets/tempo_aberto.dart';
import 'package:app/src/modulos/comandas/modelos/comanda_model.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
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

  void _updateTime() {
    // Timer.periodic(const Duration(seconds: 1), (timer) {
    //   if (mounted) {
    //     _timeStreamController.add(temporizador.main(
    //       widget.itemComanda.horaAbertura,
    //       widget.itemComanda.dataAbertura,
    //     ));
    //   } else {
    //     timer.cancel();
    //   }
    // });
  }

  @override
  void initState() {
    super.initState();

    // _timeStreamController = StreamController<String>();
    // _timeStream = _timeStreamController.stream;

    if (widget.itemComanda.comandaOcupada) {
      _updateTime();
    }
  }

  @override
  void dispose() {
    // _timeStreamController.close();
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
                  builder: (context) => PaginaComandaDesocupada(id: widget.itemComanda.id, nome: widget.itemComanda.nome),
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
                    Text(
                      widget.itemComanda.nomeCliente != null && widget.itemComanda.nomeCliente!.isNotEmpty ? widget.itemComanda.nomeCliente! : 'Diversos',
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
                          widget.itemComanda.nomeMesa != null && widget.itemComanda.nomeMesa!.isNotEmpty ? 'Mesa: ${widget.itemComanda.nomeMesa!.split(' ')[1]}' : '',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: widget.itemComanda.comandaOcupada ? Colors.black : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Row(
                      children: [
                        TempoAberto(),
                        SizedBox(width: 15),
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
