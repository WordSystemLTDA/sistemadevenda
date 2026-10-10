import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/filtros_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'delivery_test.dart';

class _ServicoPeriodo extends ServicoDeliveryTeste {
  final periodos = <DateTimeRange>[];
  @override
  Future<List<EtapaDelivery>> listar(
      {required DateTime inicio,
      required DateTime fim,
      required String horaInicio,
      required String horaFim,
      String pesquisa = '',
      String tipo = '0'}) async {
    periodos.add(DateTimeRange(start: inicio, end: fim));
    // A API inclui o dia anterior antes das 05:00 a partir da data selecionada.
    return [
      EtapaDelivery.fromMap({
        'id': '1',
        'nomeOpcao': 'AGUARDANDO',
        'vendas': [
          if (fim == DateTime(2026, 10, 10))
            pedidoTeste(campos: {
              'id': '31',
              'numeroPedido': '31',
              'nomeCliente': 'Pedido da madrugada',
              'dataAbertura': '2026-10-10 00:35:00'
            }).dados,
        ]
      })
    ];
  }
}

void main() {
  test('Hoje acompanha a virada do dia sem recriar o provedor', () async {
    var agora = DateTime(2026, 10, 9, 23, 58);
    final servico = _ServicoPeriodo();
    final provedor = ProvedorDelivery(servico, agora: () => agora);
    addTearDown(provedor.dispose);
    await provedor.listar();
    expect(provedor.etapas.single.pedidos, isEmpty);
    agora = DateTime(2026, 10, 10, 0, 36);
    await provedor.listar();
    expect(servico.periodos.last.start, DateTime(2026, 10, 10));
    expect(provedor.etapas.single.pedidos.single.id, '31');
  });

  test('periodo historico permanece fixo e Hoje volta a acompanhar a data', () {
    var agora = DateTime(2026, 10, 9);
    final provedor = ProvedorDelivery(_ServicoPeriodo(), agora: () => agora);
    addTearDown(provedor.dispose);
    provedor.periodo =
        DateTimeRange(start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 5));
    agora = DateTime(2026, 10, 10);
    expect(provedor.periodo.end, DateTime(2026, 9, 5));
    provedor.usarPeriodoDeHoje();
    expect(provedor.periodo.end, DateTime(2026, 10, 10));
  });

  testWidgets(
      'atualizacao automatica exibe pedido da madrugada sem tocar em atualizar',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    var agora = DateTime(2026, 10, 9, 23, 58);
    final provedor = ProvedorDelivery(_ServicoPeriodo(), agora: () => agora);
    addTearDown(provedor.dispose);
    await tester
        .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
    await tester.pumpAndSettle();
    expect(find.text('Pedido da madrugada'), findsNothing);
    agora = DateTime(2026, 10, 10, 0, 36);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Pedido da madrugada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
      'aplicar filtro aberto antes da meia-noite conserva Hoje dinamico',
      (tester) async {
    var agora = DateTime(2026, 10, 9, 23, 58);
    final provedor = ProvedorDelivery(_ServicoPeriodo(), agora: () => agora);
    addTearDown(provedor.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => FiltrosDelivery(provedor: provedor)),
                child: const Text('Abrir')))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    agora = DateTime(2026, 10, 10, 0, 36);
    await tester.tap(find.text('Aplicar'));
    await tester.pumpAndSettle();
    expect(provedor.acompanhaHoje, true);
    expect(provedor.periodo.start, DateTime(2026, 10, 10));
  });
}
