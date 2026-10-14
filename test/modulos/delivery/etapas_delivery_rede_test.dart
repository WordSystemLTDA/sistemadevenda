import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/etapas_delivery_rede.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final etapas = [
    EtapaDelivery.fromMap(
        {'id': '10', 'nomeOpcao': 'AGUARDANDO', 'tipodeimpressao': '0'}),
    EtapaDelivery.fromMap(
        {'id': '20', 'nomeOpcao': 'PREPARANDO', 'tipodeimpressao': '1'}),
  ];
  PedidoDelivery pedido(
          {bool recebido = true,
          bool preparando = false,
          bool rascunho = false}) =>
      PedidoDelivery.fromMap({
        'id': 'delivery-local:${rascunho ? 'rascunho' : 'pedido'}',
        'faseLocal': rascunho ? 'rascunho' : 'enfileirado',
        'recebidoNaRede': recebido,
        'etapaDeliveryRede': preparando ? 'preparando' : 'aguardando',
        'estadoSincronizacao': 'pendente',
      });
  test(
      'ACK coloca pedido em Aguardando; preparo confirmado muda a etapa sem apagar fila',
      () {
    final inicial = mesclarEtapasDeliveryRede(etapas, [pedido()]);
    expect(inicial.map((e) => e.id), ['10', '20']);
    expect(inicial.first.pedidos.single.etapa, '10');
    expect(inicial.first.pedidos.single.aguardandoSincronizacao, isTrue);
    final preparado =
        mesclarEtapasDeliveryRede(etapas, [pedido(preparando: true)]);
    expect(preparado.first.pedidos, isEmpty);
    expect(preparado.last.pedidos.single.etapa, '20');
  });
  test(
      'rascunhos e pedidos ainda nao recebidos continuam no aparelho; Online intacto',
      () {
    final lista = mesclarEtapasDeliveryRede(
        etapas, [pedido(recebido: false), pedido(rascunho: true)]);
    expect(lista.first.id, 'local');
    expect(lista.first.pedidos, hasLength(2));
    expect(lista[1].pedidos, isEmpty);
    expect(
        mesclarEtapasDeliveryRede(etapas, []).map((e) => e.id), ['10', '20']);
  });
  test('API em Aguardando nao duplica nem regride a copia ja em Preparo', () {
    final copia = PedidoDelivery.fromMap({
      ...pedido(preparando: true).dados,
      'idDeliveryConfirmado': '77',
      'estadoSincronizacao': 'concluido'
    });
    final quadro = mesclarEtapasDeliveryRede([
      EtapaDelivery.comPedidos(etapas.first, [
        PedidoDelivery.fromMap({'id': '77'})
      ]),
      etapas.last,
    ], [
      copia
    ]);
    expect(quadro.first.pedidos, isEmpty);
    expect(quadro.last.pedidos.single.preparandoNaRede, isTrue);
    expect(quadro.last.pedidos.single.etapa, '20');
  });
  test('primeiro pedido sem resposta HTTP gera quadro Aguardando/Preparo', () {
    final lista = mesclarEtapasDeliveryRede([], [pedido()]);
    expect(lista.first.nome, 'AGUARDANDO');
    expect(lista.first.pedidos.single.recebidoNaRede, isTrue);
  });
}
