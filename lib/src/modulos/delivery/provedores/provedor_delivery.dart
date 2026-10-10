import 'package:app/src/essencial/api/socket/atualizacao_agrupada.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:flutter/material.dart';

class ProvedorDelivery extends ChangeNotifier {
  final ServicoDelivery servico;
  ProvedorDelivery(this.servico, {DateTime Function()? agora})
      : _agora = agora ?? DateTime.now;
  final DateTime Function() _agora;

  List<EtapaDelivery> etapas = [];
  ConfigDelivery? config;
  bool carregando = false;
  String? erro;
  OrdenacaoPedidosDelivery _ordenacao = OrdenacaoPedidosDelivery.maisRecente;
  OrdenacaoPedidosDelivery get ordenacao => _ordenacao;
  set ordenacao(OrdenacaoPedidosDelivery valor) {
    if (_ordenacao == valor) return;
    _ordenacao = valor;
    etapas = _ordenarEtapas(etapas);
    notifyListeners();
  }

  String pesquisa = '',
      tipo = '0',
      horaInicio = '05:00:00',
      horaFim = '05:00:00';
  DateTimeRange? _periodoSelecionado;
  bool get acompanhaHoje => _periodoSelecionado == null;
  DateTimeRange get periodo {
    final selecionado = _periodoSelecionado;
    if (selecionado != null) return selecionado;
    final hoje = DateUtils.dateOnly(_agora());
    return DateTimeRange(start: hoje, end: hoje);
  }

  set periodo(DateTimeRange valor) => _periodoSelecionado = valor;
  void usarPeriodoDeHoje() => _periodoSelecionado = null;
  int _consulta = 0;
  bool _descartado = false;
  final _pedidosRecentes = <String, ({PedidoDelivery pedido, DateTime ate})>{};

  final _atualizacao = AtualizacaoAgrupada();

  Future<void> listar({bool mostrarCarregamento = true}) async {
    if (_descartado) return;
    final consulta = ++_consulta;
    // O retorno da finalizacao pode aguardar uma consulta ja em andamento.
    // Sinaliza essa espera agora, conservando a lista que ja esta na tela.
    if (mostrarCarregamento) {
      carregando = true;
      notifyListeners();
    }
    await _atualizacao.executar(() async {
      erro = null;
      try {
        final periodoConsulta = periodo;
        final configuracaoFutura = servico.configuracao().then<ConfigDelivery?>(
            (valor) => valor,
            onError: (Object _, StackTrace __) => null);
        final lista = await servico.listar(
            inicio: periodoConsulta.start,
            fim: periodoConsulta.end,
            horaInicio: horaInicio,
            horaFim: horaFim,
            pesquisa: pesquisa,
            tipo: tipo);
        if (_descartado || consulta != _consulta) return;
        etapas = _ordenarEtapas(_mesclarPedidosRecentes(lista));
        // A lista recebida ja pode ser exibida. Uma consulta auxiliar lenta
        // de configuracao nao segura Aguardando nem o ACK recebido pelo Wi-Fi.
        carregando = false;
        notifyListeners();
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
    if (pedido.salvoNoAparelho &&
        pedido.texto('estadoSincronizacao') == 'concluido' &&
        (int.tryParse(pedido.texto('idDeliveryConfirmado')) ?? 0) > 0 &&
        pedido.dados['preparoRedePendente'] != true) {
      // A notificacao final pode chegar depois do recibo oficial. Nao
      // reintroduzir seu ID provisório em No aparelho por mais 45 segundos.
      removerPedido(pedido.id);
      return;
    }
    _pedidosRecentes[pedido.id] =
        (pedido: pedido, ate: DateTime.now().add(validade));
    etapas = _ordenarEtapas(_mesclarPedidosRecentes(etapas));
    notifyListeners();
  }

  void moverPedidoParaEtapa(PedidoDelivery pedido, String etapa,
          {Duration validade = const Duration(seconds: 45)}) =>
      atualizarPedido(pedido.comEtapa(etapa), validade: validade);

  void removerPedido(String id) {
    _pedidosRecentes.remove(id);
    etapas = [
      for (final etapa in etapas)
        EtapaDelivery.comPedidos(
          etapa,
          etapa.pedidos.where((pedido) => pedido.id != id).toList(),
        ),
    ];
    notifyListeners();
  }

  List<EtapaDelivery> _ordenarEtapas(List<EtapaDelivery> origem) => [
        for (final etapa in origem)
          EtapaDelivery.comPedidos(
            etapa,
            [...etapa.pedidos]..sort(_compararPedidos),
          ),
      ];

  int _compararPedidos(PedidoDelivery a, PedidoDelivery b) {
    final aberturaA = a.abertura;
    final aberturaB = b.abertura;
    // Datas ausentes ficam ao fim; códigos desempatam horários iguais.
    if (aberturaA == null && aberturaB != null) return 1;
    if (aberturaA != null && aberturaB == null) return -1;
    var comparacao = aberturaA != null && aberturaB != null
        ? aberturaA.compareTo(aberturaB)
        : 0;
    if (comparacao == 0) {
      final idA = int.tryParse(a.id);
      final idB = int.tryParse(b.id);
      if (idA != null && idB != null) {
        comparacao = idA.compareTo(idB);
      } else if (idA != null) {
        comparacao = -1;
      } else if (idB != null) {
        comparacao = 1;
      } else {
        comparacao = a.id.compareTo(b.id);
      }
    }
    return _ordenacao == OrdenacaoPedidosDelivery.maisRecente
        ? -comparacao
        : comparacao;
  }

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
      // O ACK do PC prevalece sobre a exibicao otimista do rascunho local.
      return item.ate.isBefore(agora) ||
          confirmado ||
          remoto?.recebidoNaRede == true && item.pedido.salvoNoAparelho;
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
