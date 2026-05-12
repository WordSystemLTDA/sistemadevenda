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

  Timer? _tickerTempoLancado;
  StreamController<String> tempoLancadoController = StreamController<String>.broadcast();
  StreamController<String> dataUltimoPedidoLancadoController = StreamController<String>.broadcast();

  void _updateTimer() {
    if (widget.itemComanda.dataAbertura != null) {
      final duration = DateTime.now().difference(DateTime.parse(widget.itemComanda.dataAbertura!));
      tempoLancadoController.add(ConfigSistema.formatarHora(duration));

      if (DateTime.tryParse(widget.itemComanda.dataultimopedido ?? '') != null) {
        final durationPedido = DateTime.now().difference(DateTime.parse(widget.itemComanda.dataultimopedido!));
        dataUltimoPedidoLancadoController.add(ConfigSistema.formatarHora(durationPedido));
      }
    }
  }

  @override
  void initState() {
    super.initState();

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

  void _abrir() {
    final item = widget.itemComanda;
    if (!item.comandaOcupada) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaginaComandaDesocupada(
            id: item.id,
            idComandaPedido: item.idComandaPedido,
            nome: item.nome,
            tipo: TipoCardapio.comanda,
          ),
        ),
      );
      return;
    }

    final modo = usuarioProvedor.usuario?.configuracoes?.modaladdcomanda;
    if (modo == '1') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaginaDetalhesPedido(
            idComandaPedido: item.idComandaPedido,
            idComanda: item.id,
            tipo: TipoCardapio.comanda,
          ),
        ),
      );
    } else if (modo == '2') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaginaDetalhesPedido(
            idComandaPedido: item.idComandaPedido,
            idComanda: item.id,
            tipo: TipoCardapio.comanda,
            abrirModalFecharDireto: true,
          ),
        ),
      );
    } else if (modo == '3') {
      if (item.fechamento == true) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PaginaDetalhesPedido(
              idComandaPedido: item.idComandaPedido,
              idComanda: item.id,
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
            idComanda: item.id,
            idMesa: item.idmesa,
            idCliente: item.idCliente,
            id: item.idComandaPedido,
          );
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.itemComanda;
    final ocupada = item.comandaOcupada;
    final emFechamento = item.fechamento == true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color corStatus = !ocupada
        ? const Color(0xFF22C55E)
        : emFechamento
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    final String labelStatus = !ocupada
        ? 'Livre'
        : emFechamento
            ? 'Em fechamento'
            : 'Ocupada';

    final Color corCardBase = isDark ? const Color(0xFF1F2937) : Colors.white;
    final Color corBorda = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE5E7EB);
    final Color corSubtle = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: corCardBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: corBorda, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _abrir,
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: corStatus,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _BadgeStatus(cor: corStatus, label: labelStatus),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.nome,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ),
                        if (item.idComandaPedido != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: corStatus.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '#${item.idComandaPedido}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: corStatus,
                              ),
                            ),
                          ),
                        ],
                        if (ocupada)
                          MenuAnchor(
                            builder: (context, controller, child) {
                              return IconButton(
                                visualDensity: VisualDensity.compact,
                                iconSize: 20,
                                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                                icon: Icon(Icons.more_vert, color: corSubtle),
                              );
                            },
                            menuChildren: [
                              MenuItemButton(
                                onPressed: () {},
                                leadingIcon: Icon(Icons.tag, size: 18, color: corSubtle),
                                child: Text('ID: ${item.id}'),
                              ),
                              MenuItemButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => PaginaDetalhesPedido(
                                        idComandaPedido: item.idComandaPedido,
                                        idComanda: item.id,
                                        tipo: TipoCardapio.comanda,
                                      ),
                                    ),
                                  );
                                },
                                leadingIcon: const Icon(Icons.receipt_long_outlined, size: 18, color: Color(0xFF3B82F6)),
                                child: const Text('Abrir Comanda'),
                              ),
                            ],
                          )
                        else
                          const SizedBox(width: 8),
                      ],
                    ),
                    if (!ocupada) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.history_rounded, size: 14, color: corSubtle),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              DateTime.tryParse(item.ultimaVezAbertoDataHora ?? '') != null ? 'Última abertura: ${ConfigSistema.formatarHora(DateTime.now().difference(DateTime.parse(item.ultimaVezAbertoDataHora!)))}' : 'Nunca utilizada',
                              style: TextStyle(fontSize: 12, color: corSubtle),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (ocupada) ...[
                      const SizedBox(height: 10),
                      _LinhaInfo(
                        icone: Icons.person_outline_rounded,
                        texto: () {
                          if ((item.nomeCliente ?? '').isEmpty && (item.obs ?? '').isNotEmpty) {
                            return item.obs!;
                          }
                          if ((item.nomeCliente ?? '').isNotEmpty) return item.nomeCliente!;
                          return 'Sem cliente';
                        }(),
                        textoCor: isDark ? Colors.grey[100] : const Color(0xFF111827),
                        bold: true,
                        corIcone: corSubtle,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<String>(
                              stream: tempoLancadoController.stream,
                              initialData: '...',
                              builder: (context, snapshot) {
                                return _LinhaInfo(
                                  icone: Icons.schedule_rounded,
                                  texto: 'Aberta há ${snapshot.data!}',
                                  corIcone: corSubtle,
                                  textoCor: corSubtle,
                                );
                              },
                            ),
                          ),
                          if (item.nomeMesa != null && item.nomeMesa!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.table_restaurant_outlined, size: 12, color: Color(0xFF3B82F6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    item.nomeMesa!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF3B82F6),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<String>(
                              stream: dataUltimoPedidoLancadoController.stream,
                              initialData: '...',
                              builder: (context, snapshot) {
                                final temData = DateTime.tryParse(item.dataultimopedido ?? '') != null;
                                return _LinhaInfo(
                                  icone: Icons.restaurant_menu_rounded,
                                  texto: temData ? 'Último pedido há ${snapshot.data!}' : 'Nenhum item lançado',
                                  corIcone: corSubtle,
                                  textoCor: corSubtle,
                                );
                              },
                            ),
                          ),
                          Text(
                            double.parse(item.valor ?? '0').obterReal(),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: corStatus,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgeStatus extends StatelessWidget {
  final Color cor;
  final String label;
  const _BadgeStatus({required this.cor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: cor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: cor.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: cor,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaInfo extends StatelessWidget {
  final IconData icone;
  final String texto;
  final Color? corIcone;
  final Color? textoCor;
  final bool bold;
  const _LinhaInfo({
    required this.icone,
    required this.texto,
    this.corIcone,
    this.textoCor,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icone, size: 14, color: corIcone),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
              color: textoCor,
            ),
          ),
        ),
      ],
    );
  }
}
