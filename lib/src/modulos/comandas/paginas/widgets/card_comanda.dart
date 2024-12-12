import 'dart:async';

import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/comandas/modelos/modelo_comanda.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardComanda extends StatefulWidget {
  final ModeloComanda itemComanda;
  const CardComanda({super.key, required this.itemComanda});

  @override
  State<CardComanda> createState() => _CardComandaState();
}

class _CardComandaState extends State<CardComanda> {
  UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  // late Stream<String> _timeStream;

  // final Temporizador temporizador = Temporizador();

  Timer? _tickerTempoLancado;
  // antiga animação card produto
  StreamController<String> tempoLancadoController = StreamController<String>.broadcast();
  StreamController<String> dataUltimoPedidoLancadoController = StreamController<String>.broadcast();

  void _updateTimer() {
    if (widget.itemComanda.dataAbertura != null) {
      final duration = DateTime.now().difference(DateTime.parse(widget.itemComanda.dataAbertura!));
      final newDuration = ConfigSistema.formatarHora(duration);

      tempoLancadoController.add(newDuration);

      if (DateTime.tryParse(widget.itemComanda.dataultimopedido ?? '') != null) {
        final durationPedido = DateTime.now().difference(DateTime.parse(widget.itemComanda.dataultimopedido!));
        final newDurationPedido = ConfigSistema.formatarHora(durationPedido);

        dataUltimoPedidoLancadoController.add(newDurationPedido);
      }
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
      dataUltimoPedidoLancadoController.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.itemComanda.comandaOcupada ? null : 75,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            Container(
              padding: widget.itemComanda.comandaOcupada ? const EdgeInsets.only(bottom: 10, top: 10) : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(width: 0.5, color: Colors.grey),
              ),
              child: InkWell(
                onTap: () {
                  if (!widget.itemComanda.comandaOcupada) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaginaComandaDesocupada(
                          id: widget.itemComanda.id,
                          idComandaPedido: widget.itemComanda.idComandaPedido,
                          nome: widget.itemComanda.nome,
                          tipo: TipoCardapio.comanda,
                        ),
                      ),
                    );
                  } else {
                    if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '1') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PaginaDetalhesPedido(
                            idComandaPedido: widget.itemComanda.idComandaPedido,
                            idComanda: widget.itemComanda.id,
                            tipo: TipoCardapio.comanda,
                          ),
                        ),
                      );
                    } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '2') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PaginaDetalhesPedido(
                            idComandaPedido: widget.itemComanda.idComandaPedido,
                            idComanda: widget.itemComanda.id,
                            tipo: TipoCardapio.comanda,
                            abrirModalFecharDireto: true,
                          ),
                        ),
                      );
                    } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '3') {
                      if (widget.itemComanda.fechamento == true) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaginaDetalhesPedido(
                              idComandaPedido: widget.itemComanda.idComandaPedido,
                              idComanda: widget.itemComanda.id,
                              tipo: TipoCardapio.comanda,
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) {
                          return PaginaCardapio(
                            tipo: TipoCardapio.comanda,
                            idComanda: widget.itemComanda.id,
                            idMesa: widget.itemComanda.idmesa,
                            idCliente: widget.itemComanda.idCliente,
                            id: widget.itemComanda.idComandaPedido,
                          );
                        },
                      ));
                    }
                  }
                },
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              // const SizedBox(width: 15),
                              // const Icon(Icons.topic_outlined, size: 24),
                              const SizedBox(width: 10),
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 2 - 70,
                                child: Text(
                                  widget.itemComanda.nome,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const Spacer(),
                              if (widget.itemComanda.idComandaPedido != null) Text('#${widget.itemComanda.idComandaPedido}'),
                            ],
                          ),
                        ),
                        if (widget.itemComanda.comandaOcupada)
                          MenuAnchor(
                            builder: (BuildContext context, MenuController controller, Widget? child) {
                              return SizedBox(
                                width: 50,
                                child: InkWell(
                                  borderRadius: const BorderRadius.only(bottomRight: Radius.circular(10)),
                                  onTap: () {
                                    if (controller.isOpen) {
                                      controller.close();
                                    } else {
                                      controller.open();
                                    }
                                  },
                                  child: const Icon(Icons.more_vert),
                                ),
                              );
                            },
                            menuChildren: [
                              SizedBox(
                                height: 30,
                                child: MenuItemButton(
                                  onPressed: () async {},
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text("ID: ${widget.itemComanda.id}"),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(),
                              SizedBox(
                                height: 30,
                                child: MenuItemButton(
                                  onPressed: () async {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => PaginaDetalhesPedido(
                                          idComandaPedido: widget.itemComanda.idComandaPedido,
                                          idComanda: widget.itemComanda.id,
                                          tipo: TipoCardapio.comanda,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Text("Abrir Comanda"),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const Divider(),
                    if (widget.itemComanda.comandaOcupada == false) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, top: 1, right: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (DateTime.tryParse(widget.itemComanda.ultimaVezAbertoDataHora ?? '') != null) ...[
                              Text('Última Abertura: ${ConfigSistema.formatarHora((DateTime.now().difference(DateTime.parse(widget.itemComanda.ultimaVezAbertoDataHora ?? ''))))}',
                                  style: const TextStyle(color: Color.fromARGB(255, 93, 93, 93))),
                            ] else ...[
                              const Text('Nunca Utilizada', style: TextStyle(color: Color.fromARGB(255, 93, 93, 93))),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (widget.itemComanda.comandaOcupada) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // const SizedBox(width: 15),
                            SizedBox(
                              width: 180,
                              child: Text(
                                widget.itemComanda.nomeCliente != null && widget.itemComanda.nomeCliente!.isNotEmpty ? widget.itemComanda.nomeCliente! : 'Sem Cliente',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: widget.itemComanda.comandaOcupada ? null : Colors.grey[600],
                                ),
                              ),
                            ),
                            // StreamBuilder<String>(
                            //   stream: tempoLancadoController.stream,
                            //   initialData: 'Carregando',
                            //   builder: (context, snapshot) {
                            //     return Text("Aberta em ${snapshot.data!}", style: const TextStyle(fontSize: 12));
                            //   },
                            // ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Padding(
                        padding: const EdgeInsets.only(left: 15),
                        child: StreamBuilder<String>(
                          stream: tempoLancadoController.stream,
                          initialData: 'Carregando',
                          builder: (context, snapshot) {
                            return Text("Aberta em ${snapshot.data!}", style: const TextStyle(fontSize: 12));
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, top: 1, right: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            StreamBuilder<String>(
                              stream: dataUltimoPedidoLancadoController.stream,
                              initialData: 'Carregando',
                              builder: (context, snapshot) {
                                if (DateTime.tryParse(widget.itemComanda.dataultimopedido ?? '') == null) {
                                  return const Text("Nenhum item lançado", style: TextStyle(fontSize: 12));
                                }

                                return Text("Último item lançado à ${snapshot.data!}", style: const TextStyle(fontSize: 12));
                              },
                            ),
                            Text(double.parse(widget.itemComanda.valor ?? '0').obterReal(), style: const TextStyle(fontWeight: FontWeight.w600))
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
                                  (widget.itemComanda.nomeMesa != null && widget.itemComanda.nomeMesa!.isNotEmpty) ? widget.itemComanda.nomeMesa! : '',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: widget.itemComanda.comandaOcupada ? null : Colors.grey[600],
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
            Positioned(
              left: -6,
              bottom: 0,
              top: 0,
              child: VerticalDivider(
                color: widget.itemComanda.comandaOcupada ? Colors.red : Colors.green,
                thickness: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
