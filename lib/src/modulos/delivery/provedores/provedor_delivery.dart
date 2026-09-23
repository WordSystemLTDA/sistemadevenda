import 'package:app/src/essencial/api/socket/atualizacao_agrupada.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';

class ProvedorDelivery extends ChangeNotifier {
  final ServicoDelivery servico;
  ProvedorDelivery(this.servico);

  List<EtapaDelivery> etapas = [];
  ConfigDelivery? config;
  bool carregando = false;
  String? erro;
  String pesquisa = '',
      tipo = '0',
      horaInicio = '05:00:00',
      horaFim = '05:00:00';
  DateTimeRange periodo =
      DateTimeRange(start: DateTime.now(), end: DateTime.now());
  int _consulta = 0;
  bool _descartado = false;
  final _pedidosRecentes = <String, ({PedidoDelivery pedido, DateTime ate})>{};

  final _atualizacao = AtualizacaoAgrupada();

  Future<void> listar({bool mostrarCarregamento = true}) async {
    final consulta = ++_consulta;
    await _atualizacao.executar(() async {
      if (mostrarCarregamento && etapas.isEmpty) {
        carregando = true;
        notifyListeners();
      }
      erro = null;
      try {
        final configuracaoFutura = servico.configuracao().then<ConfigDelivery?>(
            (valor) => valor,
            onError: (Object _, StackTrace __) => null);
        final lista = await servico.listar(
            inicio: periodo.start,
            fim: periodo.end,
            horaInicio: horaInicio,
            horaFim: horaFim,
            pesquisa: pesquisa,
            tipo: tipo);
        if (_descartado || consulta != _consulta) return;
        etapas = _mesclarPedidosRecentes(lista);
        // Os rascunhos precisam continuar acessiveis mesmo se a configuracao
        // ainda nao foi preparada. Operacoes remotas consultam-na antes de agir.
        final configuracao = await configuracaoFutura;
        if (_descartado || consulta != _consulta) return;
        if (configuracao != null) {
          config = configuracao;
        } else if (!lista.any((etapa) => etapa.id == 'local')) {
          throw StateError(
              'Não foi possível consultar a configuração do Delivery.');
        }
      } catch (_) {
        if (_descartado || consulta != _consulta) return;
        erro =
            'Não foi possível atualizar o Delivery. Verifique a conexão e tente novamente.';
      } finally {
        if (!_descartado && consulta == _consulta) {
          carregando = false;
          notifyListeners();
        }
      }
    });
  }

  void atualizarPedido(PedidoDelivery pedido,
      {Duration validade = const Duration(seconds: 45)}) {
    _pedidosRecentes[pedido.id] =
        (pedido: pedido, ate: DateTime.now().add(validade));
    etapas = _mesclarPedidosRecentes(etapas);
    notifyListeners();
  }

  void moverPedidoParaEtapa(PedidoDelivery pedido, String etapa,
          {Duration validade = const Duration(seconds: 45)}) =>
      atualizarPedido(pedido.comEtapa(etapa), validade: validade);

  List<EtapaDelivery> _mesclarPedidosRecentes(List<EtapaDelivery> origem) {
    if (_pedidosRecentes.isEmpty || origem.isEmpty) return origem;
    final agora = DateTime.now();
    final remotos = {
      for (final etapa in origem)
        for (final pedido in etapa.pedidos) pedido.id: pedido
    };
    _pedidosRecentes.removeWhere((id, item) {
      final remoto = remotos[id];
      final confirmado = remoto != null &&
          remoto.etapa == item.pedido.etapa &&
          remoto.quantidade >= item.pedido.quantidade &&
          remoto.pago >= item.pedido.pago - 0.009 &&
          remoto.total >= item.pedido.total - 0.009;
      return item.ate.isBefore(agora) || confirmado;
    });
    if (_pedidosRecentes.isEmpty) return origem;
    return [for (final etapa in origem) _mesclarPedidosDaEtapa(etapa)];
  }

  EtapaDelivery _mesclarPedidosDaEtapa(EtapaDelivery etapa) {
    final pedidos = <PedidoDelivery>[];
    final ids = <String>{};

    for (final remoto in etapa.pedidos) {
      final recente = _pedidosRecentes[remoto.id]?.pedido;
      if (recente != null && recente.etapa != etapa.id) continue;
      final pedido = _pedidoMaisCompleto(remoto, recente);
      pedidos.add(pedido);
      ids.add(pedido.id);
    }

    for (final item in _pedidosRecentes.values) {
      if (item.pedido.etapa == etapa.id && ids.add(item.pedido.id)) {
        pedidos.add(item.pedido);
      }
    }

    return EtapaDelivery.comPedidos(etapa, pedidos);
  }

  PedidoDelivery _pedidoMaisCompleto(
      PedidoDelivery remoto, PedidoDelivery? recente) {
    if (recente == null || recente.etapa != remoto.etapa) return remoto;
    final recenteTemProdutos = recente.quantidade > remoto.quantidade;
    final recenteTemPagamento = recente.pago > remoto.pago + 0.009;
    final recenteTemTotal = recente.total > remoto.total + 0.009;
    if (recenteTemProdutos || recenteTemPagamento || recenteTemTotal) {
      return recente;
    }
    return remoto;
  }

  @override
  void dispose() {
    _descartado = true;
    _atualizacao.dispose();
    super.dispose();
  }
}
