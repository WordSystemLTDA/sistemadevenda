import 'dart:async';
import 'package:app/src/modulos/transferencias/servico_transferencias.dart';
import 'package:app/src/modulos/transferencias/transferencia_atendimento.dart';
import 'package:app/src/essencial/widgets/card_resumo_atendimento.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';

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

  Timer? _tickerTempoLancado;
  StreamController<String> tempoLancadoController =
      StreamController<String>.broadcast();
  StreamController<String> dataUltimoPedidoLancadoController =
      StreamController<String>.broadcast();

  void _updateTimer() {
    final dataAbertura = DateTime.tryParse(widget.item.dataAbertura ?? '');
    if (dataAbertura == null) {
      tempoLancadoController.add('...');
      dataUltimoPedidoLancadoController.add('...');
      return;
    }

    final duration = DateTime.now().difference(dataAbertura);
    tempoLancadoController.add(ConfigSistema.formatarHora(duration));

    final dataUltimoPedido =
        DateTime.tryParse(widget.item.dataultimopedido ?? '');
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

    if (widget.item.mesaOcupada) {
      _iniciarAtualizacaoTempo();
    }
  }

  @override
  void didUpdateWidget(covariant CardMesaOcupada oldWidget) {
    super.didUpdateWidget(oldWidget);

    final ocupadaAnterior = oldWidget.item.mesaOcupada;
    final ocupadaAtual = widget.item.mesaOcupada;

    if (ocupadaAtual && !ocupadaAnterior) {
      _iniciarAtualizacaoTempo();
      return;
    }

    if (!ocupadaAtual && ocupadaAnterior) {
      _pararAtualizacaoTempo();
      return;
    }

    if (ocupadaAtual &&
        (oldWidget.item.dataAbertura != widget.item.dataAbertura ||
            oldWidget.item.dataultimopedido != widget.item.dataultimopedido)) {
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
    final item = widget.item;
    if (!item.mesaOcupada) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaginaComandaDesocupada(
            id: item.id,
            idComandaPedido: item.idComandaPedido,
            nome: item.nome,
            tipo: TipoCardapio.mesa,
          ),
        ),
      );
      return;
    }

    final modo = usuarioProvedor.usuario?.configuracoes?.modaladdmesa;
    if (modo == '1') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaginaDetalhesPedido(
            idComandaPedido: item.idComandaPedido,
            idMesa: item.id,
            tipo: TipoCardapio.mesa,
          ),
        ),
      );
    } else if (modo == '2') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PaginaDetalhesPedido(
            idComandaPedido: item.idComandaPedido,
            idMesa: item.id,
            tipo: TipoCardapio.mesa,
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
              idMesa: item.id,
              tipo: TipoCardapio.mesa,
            ),
          ),
        );
        return;
      }

      Navigator.push(context, MaterialPageRoute(
        builder: (context) {
          return PaginaCardapio(
            nomeAtendimento: item.nome,
            tipo: TipoCardapio.mesa,
            idComanda: '0',
            idMesa: item.id,
            idCliente: item.idCliente,
            id: item.idComandaPedido,
          );
        },
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final ocupada = item.mesaOcupada;
    String decorrido(String? valor) {
      final data = DateTime.tryParse(valor ?? '');
      return data == null
          ? '...'
          : ConfigSistema.formatarHora(DateTime.now().difference(data));
    }

    final alvo = AlvoTransferencia(
        id: item.id,
        atendimento: ocupada ? (item.idComandaPedido ?? '0') : '0',
        nome: item.nome,
        tipo: 'mesa',
        livre: !ocupada,
        motivo: item.fechamento == true
            ? 'Reabra a conta antes de transferir.'
            : '');
    return AreaTransferencia(
        alvo: alvo,
        child: CardResumoAtendimento(
          nome: item.nome,
          cliente: nomeClienteAtendimento(item.nomeCliente, item.obs),
          codigo: item.codigo,
          atendimento: item.idComandaPedido,
          ocupada: ocupada,
          fechamento: item.fechamento == true,
          tipoMesa: true,
          total: usuarioProvedor
                      .usuario?.configuracoes?.habilitarVerValorTotalNoApp ==
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
              : Text(DateTime.tryParse(item.ultimaVezAbertoDataHora ?? '') !=
                      null
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
          menu: MenuAnchor(
            builder: (context, controller, child) => IconButton(
              tooltip: 'Opções da mesa',
              onPressed: () =>
                  controller.isOpen ? controller.close() : controller.open(),
              icon: const Icon(Icons.more_vert, size: 20),
            ),
            menuChildren: [
              MenuItemButton(
                  onPressed: null,
                  leadingIcon: const Icon(Icons.tag, size: 18),
                  child: Text('ID: ${item.id}')),
              if (ocupada)
                MenuItemButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => PaginaDetalhesPedido(
                      idComandaPedido: item.idComandaPedido,
                      idMesa: item.id,
                      tipo: TipoCardapio.mesa,
                    ),
                  )),
                  leadingIcon:
                      const Icon(Icons.receipt_long_outlined, size: 18),
                  child: const Text('Abrir Mesa'),
                ),
              MenuItemButton(
                onPressed: () => abrirTransferencia(context, alvo),
                leadingIcon:
                    const Icon(Icons.drive_file_move_outline, size: 18),
                child: const Text('Transferir / Juntar'),
              ),
              MenuItemButton(
                onPressed: () => abrirHistoricoTransferencias(context, alvo),
                leadingIcon: const Icon(Icons.history, size: 18),
                child: const Text('Histórico de transferências'),
              ),
            ],
          ),
        ));
  }
}
