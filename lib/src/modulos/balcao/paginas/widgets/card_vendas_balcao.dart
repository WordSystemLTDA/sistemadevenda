import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class CardVendasBalcao extends StatefulWidget {
  final ModeloVendasBalcao item;
  const CardVendasBalcao({super.key, required this.item});

  @override
  State<CardVendasBalcao> createState() => _CardVendasBalcaoState();
}

class _CardVendasBalcaoState extends State<CardVendasBalcao> {
  // Timer? _tickerTempoLancado;
  // StreamController<String> tempoLancadoController = StreamController<String>.broadcast();

  // void _updateTimer() {
  //   final duration = DateTime.now().difference(DateTime.parse(widget.item.dataAbertura));
  //   final newDuration = ConfigSistema.formatarHora(duration);

  //   tempoLancadoController.add(newDuration);
  // }

  // @override
  // void initState() {
  //   super.initState();

  //   _updateTimer();
  //   _tickerTempoLancado ??= Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
  // }

  // @override
  // void dispose() {
  //   if (_tickerTempoLancado != null) {
  //     _tickerTempoLancado!.cancel();
  //     tempoLancadoController.close();
  //   }
  //   super.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Card(
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
            // if (!widget.item.mesaOcupada) {
            //   Navigator.of(context).push(
            //     MaterialPageRoute(
            //       builder: (context) => PaginaComandaDesocupada(
            //         id: widget.item.id,
            //         idComandaPedido: widget.item.idComandaPedido,
            //         nome: widget.item.nome,
            //         tipo: TipoCardapio.mesa,
            //       ),
            //     ),
            //   );
            // } else {
            //   Navigator.of(context).push(
            //     MaterialPageRoute(
            //       builder: (context) => PaginaDetalhesPedido(
            //         idComandaPedido: widget.item.idComandaPedido,
            //         idMesa: widget.item.id,
            //         tipo: TipoCardapio.mesa,
            //       ),
            //     ),
            //   );
            // }
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
                      (double.tryParse(widget.item.subtotal) ?? 0).obterReal(),
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
              Row(
                children: [
                  const SizedBox(width: 15),
                  SizedBox(
                    width: 150,
                    child: Text(
                      widget.item.nomecliente.isNotEmpty ? widget.item.nomecliente : 'Sem Cliente',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
              // const SizedBox(height: 2),
              // Padding(
              //   padding: const EdgeInsets.only(left: 15.0, top: 1, right: 15),
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
              //     children: [
              //       StreamBuilder<String>(
              //         stream: tempoLancadoController.stream,
              //         initialData: 'Carregando',
              //         builder: (context, snapshot) {
              //           return Text(snapshot.data!, style: const TextStyle(fontSize: 12));
              //         },
              //       ),
              //       Text(double.parse(widget.item.valor).obterReal(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
              //     ],
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
