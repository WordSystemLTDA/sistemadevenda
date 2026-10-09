import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/etapas_delivery_rede.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'delivery_test.dart';

class _DeliveryWifi extends ServicoDeliveryTeste {
  bool preparando = false;
  int pedidosPreparo = 0;
  @override
  Future<List<EtapaDelivery>> listar(
          {required DateTime inicio,
          required DateTime fim,
          required String horaInicio,
          required String horaFim,
          String pesquisa = '',
          String tipo = '0'}) async =>
      mesclarEtapasDeliveryRede([
        EtapaDelivery.fromMap({
          'id': '1',
          'nomeOpcao': 'AGUARDANDO',
          'nomeBotao': 'Preparar',
          'tipodeimpressao': '0'
        }),
        EtapaDelivery.fromMap({
          'id': '2',
          'nomeOpcao': 'PREPARANDO',
          'nomeBotao': 'Pronto',
          'tipodeimpressao': '1'
        }),
      ], [
        pedidoTeste(campos: {
          'id': 'delivery-local:pedido',
          'faseLocal': 'enfileirado',
          'recebidoNaRede': true,
          'etapaDeliveryRede': preparando ? 'preparando' : 'aguardando',
          'estadoSincronizacao': 'pendente',
          'numeroPedido': '',
          'somaValorHistorico': '86',
          'produtosConfirmadosLocal': true,
        })
      ]);
  @override
  Future<void> prepararPelaRede(String id) async {
    pedidosPreparo++;
    preparando = true;
  }
}

void main() {
  for (final tamanho in [const Size(320, 640), const Size(430, 930)]) {
    testWidgets(
        'pedido via Wi-Fi aparece em Aguardando com aviso discreto em $tamanho',
        (tester) async {
      await tester.binding.setSurfaceSize(tamanho);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final servico = _DeliveryWifi();
      final provedor = ProvedorDelivery(servico);
      addTearDown(provedor.dispose);
      await tester
          .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
      await tester.pumpAndSettle();
      expect(find.text('AGUARDANDO (1)'), findsOneWidget);
      expect(find.textContaining('No aparelho'), findsNothing);
      expect(find.text('Via Wi-Fi'), findsOneWidget);
      expect(find.textContaining('Recebido pelo PC via'), findsNothing);
      expect(servico.pedidosPreparo, 0);
      final acao =
          find.byKey(const ValueKey('avancar-delivery-delivery-local:pedido'));
      await tester.ensureVisible(acao);
      await tester.tap(acao);
      await tester.pumpAndSettle();
      expect(servico.pedidosPreparo, 1);
      expect(find.text('PREPARANDO (1)'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
