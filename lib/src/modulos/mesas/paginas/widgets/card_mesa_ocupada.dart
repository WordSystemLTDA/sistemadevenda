import 'dart:async';

import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/mesas/modelos/mesa_modelo.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardMesaOcupada extends StatefulWidget {
  final MesaModelo item;
  const CardMesaOcupada({super.key, required this.item});

  @override
  State<CardMesaOcupada> createState() => _CardMesaOcupadaState();
}

class _CardMesaOcupadaState extends State<CardMesaOcupada> {
  UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  // late StreamController<String> _timeStreamController;
  // late Stream<String> _timeStream;

  // final Temporizador temporizador = Temporizador();

  Timer? _tickerTempoLancado;
  // antiga animação card produto
  StreamController<String> tempoLancadoController = StreamController<String>.broadcast();
  StreamController<String> dataUltimoPedidoLancadoController = StreamController<String>.broadcast();

  void _updateTimer() {
    if (widget.item.dataAbertura != null) {
      final duration = DateTime.now().difference(DateTime.parse(widget.item.dataAbertura!));
      final newDuration = ConfigSistema.formatarHora(duration);

      tempoLancadoController.add(newDuration);

      if (DateTime.tryParse(widget.item.dataultimopedido ?? '') != null) {
        final durationPedido = DateTime.now().difference(DateTime.parse(widget.item.dataultimopedido!));
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
      dataUltimoPedidoLancadoController.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.item.mesaOcupada ? null : 75,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
        ),
        child: Stack(
          children: [
            Container(
              padding: widget.item.mesaOcupada ? const EdgeInsets.only(bottom: 10, top: 10) : null,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(width: 0.5, color: Colors.grey),
              ),
              child: InkWell(
                onTap: () {
                  if (!widget.item.mesaOcupada) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => PaginaComandaDesocupada(
                          id: widget.item.id,
                          idComandaPedido: widget.item.idComandaPedido,
                          nome: widget.item.nome,
                          tipo: TipoCardapio.mesa,
                        ),
                      ),
                    );
                  } else {
                    if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '1') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PaginaDetalhesPedido(
                            idComandaPedido: widget.item.idComandaPedido,
                            idMesa: widget.item.id,
                            tipo: TipoCardapio.mesa,
                          ),
                        ),
                      );
                    } else if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '2') {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => PaginaDetalhesPedido(
                            idComandaPedido: widget.item.idComandaPedido,
                            idMesa: widget.item.id,
                            tipo: TipoCardapio.mesa,
                            abrirModalFecharDireto: true,
                          ),
                        ),
                      );
                    } else if (usuarioProvedor.usuario?.configuracoes?.modaladdmesa == '3') {
                      if (widget.item.fechamento == true) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => PaginaDetalhesPedido(
                              idComandaPedido: widget.item.idComandaPedido,
                              idMesa: widget.item.id,
                              tipo: TipoCardapio.mesa,
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.push(context, MaterialPageRoute(
                        builder: (context) {
                          return PaginaCardapio(
                            tipo: TipoCardapio.mesa,
                            idComanda: '0',
                            idMesa: widget.item.id,
                            idCliente: widget.item.idCliente,
                            id: widget.item.idComandaPedido,
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
                              const SizedBox(width: 10),
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 2 - 70,
                                child: Text(
                                  widget.item.nome,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const Spacer(),
                              if (widget.item.idComandaPedido != null) Text('#${widget.item.idComandaPedido}'),
                            ],
                          ),
                        ),
                        if (widget.item.mesaOcupada)
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
                                      Text("ID: ${widget.item.id}"),
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
                                          idComandaPedido: widget.item.idComandaPedido,
                                          idMesa: widget.item.id,
                                          tipo: TipoCardapio.mesa,
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Row(
                                    children: [
                                      Text("Abrir Mesa"),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    const Divider(),
                    if (widget.item.mesaOcupada == false) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 15.0, top: 1, right: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (DateTime.tryParse(widget.item.ultimaVezAbertoDataHora ?? '') != null) ...[
                              Text('Última Abertura: ${ConfigSistema.formatarHora((DateTime.now().difference(DateTime.parse(widget.item.ultimaVezAbertoDataHora ?? ''))))}',
                                  style: const TextStyle(color: Color.fromARGB(255, 93, 93, 93))),
                            ] else ...[
                              const Text('Nunca Utilizada', style: TextStyle(color: Color.fromARGB(255, 93, 93, 93))),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (widget.item.mesaOcupada) ...[
                      Row(
                        children: [
                          const SizedBox(width: 15),
                          SizedBox(
                            width: 180,
                            child: Text(
                              widget.item.nomeCliente != null && widget.item.nomeCliente!.isNotEmpty ? widget.item.nomeCliente! : 'Sem Cliente',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: widget.item.mesaOcupada ? null : Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
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
                                if (DateTime.tryParse(widget.item.dataultimopedido ?? '') == null) {
                                  return const Text("Nenhum item lançado", style: TextStyle(fontSize: 12));
                                }

                                return Text("Último item lançado à ${snapshot.data!}", style: const TextStyle(fontSize: 12));
                              },
                            ),
                            Text(double.parse(widget.item.valor ?? '0').obterReal(), style: const TextStyle(fontWeight: FontWeight.w600))
                          ],
                        ),
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
                color: widget.item.mesaOcupada ? Colors.red : Colors.green,
                thickness: 4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
