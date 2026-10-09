import '../modelos/modelo_delivery.dart';

/// O PC confirmou o recebimento. A identidade provisoria continua na fila,
/// mas o atendimento ja participa de Aguardando/Preparo na tela operacional.
List<EtapaDelivery> mesclarEtapasDeliveryRede(
    List<EtapaDelivery> etapas, List<PedidoDelivery> locais) {
  final rede = locais
      .where((p) =>
          p.recebidoNaRede && p.texto('estadoSincronizacao') != 'conflito')
      .toList();
  final oficiaisEmReconciliacao = rede
      .where((p) => p.preparandoNaRede)
      .map((p) => p.texto('idDeliveryConfirmado'))
      .where((id) => id.isNotEmpty)
      .toSet();
  final rascunhos = locais.where((p) => !rede.contains(p)).toList();
  final quadro = [...etapas];
  if (rede.isNotEmpty && quadro.isEmpty) {
    quadro.addAll([
      EtapaDelivery.fromMap({
        'id': 'rede-aguardando',
        'nomeOpcao': 'AGUARDANDO',
        'nomeBotao': 'Preparar',
        'tipodeimpressao': '0'
      }),
      EtapaDelivery.fromMap({
        'id': 'rede-preparando',
        'nomeOpcao': 'PREPARANDO',
        'nomeBotao': 'Preparando',
        'tipodeimpressao': '1'
      }),
    ]);
  }
  final preparo =
      quadro.indexWhere((e) => e.impressao == '1' || e.impressao == '4');
  final aguardando = quadro.indexWhere((e) => e.impressao == '0');
  return [
    if (rascunhos.isNotEmpty)
      EtapaDelivery.fromMap({
        'id': 'local',
        'nomeOpcao': 'No aparelho',
        'nomeBotao': 'Continuar pedido',
        'tipodeimpressao': '0',
        'vendas': rascunhos.map((p) => p.dados).toList()
      }),
    for (var i = 0; i < quadro.length; i++)
      EtapaDelivery.comPedidos(quadro[i], [
        ...quadro[i]
            .pedidos
            .where((p) => !oficiaisEmReconciliacao.contains(p.id)),
        for (final p in rede)
          if ((p.preparandoNaRede ? preparo : aguardando) == i ||
              (p.preparandoNaRede ? preparo : aguardando) < 0 && i == 0)
            PedidoDelivery.fromMap(
                {...p.dados, 'idopcoescarrossel': quadro[i].id}),
      ]),
  ];
}
