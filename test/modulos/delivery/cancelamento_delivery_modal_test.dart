import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'delivery_test.dart';
import 'pagamento_online_delivery_test.dart' show pedidoOnline;

class _ServicoCancelamento extends ServicoDeliveryTeste {
  int detalhes = 0;
  bool cancelado = false;
  Map<String, dynamic>? autorizacao;

  @override
  Future<PedidoDelivery> pedido(String id) async {
    detalhes++;
    throw StateError('Detalhe online indisponivel.');
  }

  @override
  Future<Set<String>> pedidosComCancelamentoLocal() async =>
      cancelado ? {atual.id} : {};

  @override
  Future<Map<String, dynamic>> acao(String acao, PedidoDelivery pedido,
      [Map<String, dynamic> campos = const {}]) async {
    expect(acao, 'cancelar');
    autorizacao = {...campos};
    cancelado = true;
    notificarPedidoAtualizado(PedidoDelivery.fromMap(
        {...pedido.dados, 'status': 'Cancelado', 'cancelamentoLocal': true}));
    return {'sucesso': true, 'salvo_no_aparelho': true};
  }
}

void main() {
  for (final tipo in ['5', '6']) {
    for (final largura in [320.0, 1180.0]) {
      testWidgets(
          'cancelar MP $tipo em $largura dispensa detalhe online e exige admin/motivo',
          (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = Size(largura, 850);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final servico = _ServicoCancelamento()
          ..atual = pedidoOnline(tipo: tipo, status: 'approved', liberado: true)
          ..config = const ConfigDelivery(motivoCancelamentoObrigatorio: true);
        servico.respostaLista = () async => [
              EtapaDelivery.fromMap({
                'id': '1',
                'nomeOpcao': 'Aguardando',
                'nomeBotao': 'Preparar',
                'tipodeimpressao': '0',
                'vendas': [servico.atual.dados],
              })
            ];
        final provedor = ProvedorDelivery(servico);
        addTearDown(provedor.dispose);
        await tester
            .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Opções do pedido #14'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Cancelar Venda'), 300,
            scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('Cancelar Venda'));
        await tester.pumpAndSettle();
        expect(servico.detalhes, 0);
        await tester.ensureVisible(find.text('Confirmar'));
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(find.text('Informe a senha Admin.'), findsOneWidget);
        final campos = find.byType(TextField);
        await tester.enterText(campos.at(1), 'admin-teste');
        await tester.ensureVisible(find.text('Confirmar'));
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(find.text('Informe o motivo do cancelamento.'), findsOneWidget);
        await tester.enterText(campos.at(2), 'Solicitado pelo cliente');
        await tester.ensureVisible(find.text('Confirmar'));
        await tester.tap(find.text('Confirmar'));
        await tester.pumpAndSettle();
        expect(servico.autorizacao,
            {'senha': 'admin-teste', 'motivo': 'Solicitado pelo cliente'});
        expect(provedor.etapas.single.pedidos, isEmpty);
        expect(servico.detalhes, 0);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}
