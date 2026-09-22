import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delivery_test.dart';

class _Modulo extends Module {
  _Modulo(this.provedor);
  final ProvedorDelivery provedor;
  @override
  void binds(Injector i) => i.addInstance<ProvedorDelivery>(provedor);
}

void main() {
  testWidgets('socket atualiza o mesmo delivery que esta visivel', (tester) async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    Modular.init(_Modulo(provedor));
    addTearDown(Modular.destroy);
    await tester.pumpWidget(const MaterialApp(home: PaginaDelivery()));
    await tester.pumpAndSettle();
    final antes = servico.consultas;
    servico.respostaLista = () async => [
      EtapaDelivery.fromMap({'id': '99', 'nomeOpcao': 'Pedido recebido agora', 'vendas': []}),
    ];
    AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: 'delivery'));
    await tester.pumpAndSettle();
    expect(servico.consultas, antes + 1);
    expect(provedor.etapas.single.id, '99');
    expect(find.textContaining('Pedido recebido agora'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  test('confirmacao remota libera imediatamente mudancas de outro terminal', () async {
    final servico = ServicoDeliveryTeste();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    var etapaAtual = '1';
    final pedido = pedidoTeste();
    servico.respostaLista = () async => [
      for (final etapa in ['1', '2', '3'])
        EtapaDelivery.fromMap({'id': etapa, 'vendas': [if (etapa == etapaAtual) pedido.comEtapa(etapa).dados]}),
    ];
    await provedor.listar();
    provedor.moverPedidoParaEtapa(pedido, '2');
    etapaAtual = '2';
    await provedor.listar();
    etapaAtual = '3';
    await provedor.listar();
    expect(provedor.etapas[1].pedidos, isEmpty);
    expect(provedor.etapas[2].pedidos.single.id, pedido.id);
  });
}
