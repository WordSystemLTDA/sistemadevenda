import 'dart:async';
import 'package:app/src/essencial/widgets/card_resumo_atendimento.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';

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
  StreamController<String> tempoLancadoController =
      StreamController<String>.broadcast();
  StreamController<String> dataUltimoPedidoLancadoController =
      StreamController<String>.broadcast();

  void _updateTimer() {
    final dataAbertura =
        DateTime.tryParse(widget.itemComanda.dataAbertura ?? '');
    if (dataAbertura == null) {
      tempoLancadoController.add('...');
      dataUltimoPedidoLancadoController.add('...');
      return;
    }

    final duration = DateTime.now().difference(dataAbertura);
    tempoLancadoController.add(ConfigSistema.formatarHora(duration));

    final dataUltimoPedido =
        DateTime.tryParse(widget.itemComanda.dataultimopedido ?? '');
    if (dataUltimoPedido != null) {
      final durationPedido = DateTime.now().difference(dataUltimoPedido);
      dataUltimoPedidoLancadoController
          .add(ConfigSistema.formatarHora(durationPedido));
    } else {
      dataUltimoPedidoLancadoController.add('...');
    }
  }

  void _iniciarAtualizacaoTempo() {
    _updateTimer();
    _tickerTempoLancado?.cancel();
    _tickerTempoLancado = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _updateTimer(),
    );
  }

  void _pararAtualizacaoTempo() {
    _tickerTempoLancado?.cancel();
    _tickerTempoLancado = null;
  }

  @override
  void initState() {
    super.initState();

    if (widget.itemComanda.comandaOcupada) {
      _iniciarAtualizacaoTempo();
    }
  }

  @override
  void didUpdateWidget(covariant CardComanda oldWidget) {
    super.didUpdateWidget(oldWidget);

    final ocupadaAnterior = oldWidget.itemComanda.comandaOcupada;
    final ocupadaAtual = widget.itemComanda.comandaOcupada;

    if (ocupadaAtual && !ocupadaAnterior) {
      _iniciarAtualizacaoTempo();
      return;
    }

    if (!ocupadaAtual && ocupadaAnterior) {
      _pararAtualizacaoTempo();
      return;
    }

    if (ocupadaAtual &&
        (oldWidget.itemComanda.dataAbertura !=
                widget.itemComanda.dataAbertura ||
            oldWidget.itemComanda.dataultimopedido !=
                widget.itemComanda.dataultimopedido)) {
      _updateTimer();
    }
  }

  @override
  void dispose() {
    _pararAtualizacaoTempo();
    tempoLancadoController.close();
    dataUltimoPedidoLancadoController.close();
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
            nomeAtendimento: item.nome,
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
    String decorrido(String? valor) {
      final data = DateTime.tryParse(valor ?? '');
      return data == null
          ? '...'
          : ConfigSistema.formatarHora(DateTime.now().difference(data));
    }

    return CardResumoAtendimento(
      nome: item.nome,
      cliente: nomeClienteAtendimento(item.nomeCliente, item.obs),
      codigo: item.codigo,
      atendimento: item.idComandaPedido,
      mesa: item.nomeMesa,
      ocupada: ocupada,
      fechamento: item.fechamento == true,
      tipoMesa: false,
      total:
          usuarioProvedor.usuario?.configuracoes?.habilitarVerValorTotalNoApp ==
                  'Sim'
              ? (double.tryParse(item.valor ?? '0') ?? 0).obterReal()
              : null,
      onAbrir: _abrir,
      tempo: ocupada
          ? StreamBuilder<String>(
              stream: tempoLancadoController.stream,
              initialData: decorrido(item.dataAbertura),
              builder: (_, snapshot) => Text('Aberta há ${snapshot.data}'),
            )
          : Text(DateTime.tryParse(item.ultimaVezAbertoDataHora ?? '') != null
              ? 'Última abertura: ${decorrido(item.ultimaVezAbertoDataHora)}'
              : 'Nunca utilizada'),
      ultimoPedido: !ocupada
          ? null
          : StreamBuilder<String>(
              stream: dataUltimoPedidoLancadoController.stream,
              initialData: decorrido(item.dataultimopedido),
              builder: (_, snapshot) => Text(
                  DateTime.tryParse(item.dataultimopedido ?? '') != null
                      ? 'Último pedido há ${snapshot.data}'
                      : 'Nenhum item lançado'),
            ),
      menu: !ocupada
          ? null
          : MenuAnchor(
              builder: (context, controller, child) => IconButton(
                tooltip: 'Opções da comanda',
                onPressed: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.more_vert, size: 20),
              ),
              menuChildren: [
                MenuItemButton(
                    onPressed: null,
                    leadingIcon: const Icon(Icons.tag, size: 18),
                    child: Text('ID: ${item.id}')),
                MenuItemButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PaginaDetalhesPedido(
                      idComandaPedido: item.idComandaPedido,
                      idComanda: item.id,
                      tipo: TipoCardapio.comanda,
                    ),
                  )),
                  leadingIcon:
                      const Icon(Icons.receipt_long_outlined, size: 18),
                  child: const Text('Abrir Comanda'),
                ),
              ],
            ),
    );
  }
}
