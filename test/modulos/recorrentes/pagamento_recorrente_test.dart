import 'dart:convert';

import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/paginas/widgets/campos_recorrencia.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../delivery/delivery_test.dart';

class _Pagamento extends ServicoDeliveryTeste {
  bool mensal = true;
  bool falharPrimeira = false;
  @override
  Future<PagamentoRecorrente?> pagamentoRecorrente(String id) async =>
      PagamentoRecorrente.fromMap({
        'recorrente': true,
        'pagamentoModo': mensal ? 'mensal' : 'diario',
        'diaVencimento': 10,
        'pagamentoPadrao': {
          'definida': true,
          'formaPagamento': mensal ? 2 : 5,
          'nome': mensal ? 'Em conta' : 'Pix',
          'vencimento': '2026-10-10',
        },
      });

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final resposta = await super.salvar(rota, campos);
    if (falharPrimeira && gravacoes.length == 1) {
      throw StateError('Sem confirmação do servidor. Tente novamente.');
    }
    return resposta;
  }
}

void main() {
  test('preparo mantém chave por destino e não duplica em uma repetição', () {
    final mensagens = [
      jsonEncode({
        'nomedopc': ' COZINHA ',
        'idRequisicao': 'aleatoria',
        'produtos': [1]
      }),
      jsonEncode({
        'nomedopc': 'BAR',
        'idRequisicao': 'outra',
        'produtos': [2]
      }),
    ];
    final primeira = ImpressaoDelivery.identificarPreparoRecorrente(
        mensagens, 'recorrente-3-25-preparo');
    final repeticao = ImpressaoDelivery.identificarPreparoRecorrente(
        mensagens, 'recorrente-3-25-preparo');
    expect(primeira, repeticao);
    expect(jsonDecode(primeira.first)['idRequisicao'],
        isNot(jsonDecode(primeira.last)['idRequisicao']));
    expect(jsonDecode(primeira.first)['produtos'], [1]);
  });
  test('configuração mensal preserva dia e valida limites', () {
    const mensal =
        ConfiguracaoRecorrencia(pagamentoModo: 'mensal', diaVencimento: 31);
    final copia = ConfiguracaoRecorrencia.fromMap(mensal.toMap());
    expect(copia.pagamentoModo, 'mensal');
    expect(copia.diaVencimento, 31);
    expect(copia.copyWith(diaVencimento: 0).erro, isNotNull);
    expect(copia.copyWith(diaVencimento: 32).erro, isNotNull);
    expect(copia.copyWith(dias: [2, 4]).pagamentoModo, 'mensal');
  });

  for (final tamanho in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('configuração mensal cabe em $tamanho com fonte ampliada',
        (tester) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var config = const ConfiguracaoRecorrencia(pagamentoModo: 'mensal');
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.7)),
            child: child!),
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: StatefulBuilder(
                    builder: (context, setState) => CamposRecorrencia(
                        valor: config,
                        onChanged: (valor) =>
                            setState(() => config = valor))))),
      ));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(DropdownButtonFormField<int>));
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dia 12').last);
      await tester.pumpAndSettle();
      expect(config.diaVencimento, 12);
      expect(tester.takeException(), isNull);
    });
  }

  Future<void> abrir(WidgetTester tester, _Pagamento servico) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => TextButton(
                    onPressed: () => receberDelivery(context, servico, '25',
                        confirmarRecorrente: true),
                    child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'mensal lança em conta na data combinada e reutiliza chave no retry',
      (tester) async {
    final servico = _Pagamento()..falharPrimeira = true;
    await abrir(tester, servico);
    expect(find.text('Vencimento: 10/10/2026'), findsOneWidget);
    expect(
        tester
            .widget<DropdownButtonFormField<int>>(
                find.byType(DropdownButtonFormField<int>))
            .onChanged,
        isNull);
    await tester.tap(find.text('Lançar em Conta'));
    await tester.pumpAndSettle();
    expect(find.text('Sem confirmação do servidor. Tente novamente.'),
        findsOneWidget);
    await tester.tap(find.text('Lançar em Conta'));
    await tester.pumpAndSettle();
    expect(servico.gravacoes, hasLength(2));
    final primeiro = servico.gravacoes.first.$2;
    final segundo = servico.gravacoes.last.$2;
    expect(primeiro['pagamentoSelecionado'], 2);
    expect(primeiro['confirmarRecorrente'], isTrue);
    expect(primeiro['dataLancamento'], '2026-10-10');
    expect(jsonDecode((primeiro['parcelasLista'] as List).single)['vencimento'],
        '2026-10-10');
    expect(primeiro['chavePagamento'], isNotEmpty);
    expect(segundo['chavePagamento'], primeiro['chavePagamento']);
  });

  testWidgets('diário sugere o primeiro Pix sem receber antes da confirmação',
      (tester) async {
    final servico = _Pagamento()..mensal = false;
    await abrir(tester, servico);
    expect(find.text('Pix · a cada pedido'), findsOneWidget);
    expect(servico.gravacoes, isEmpty);
    await tester.tap(find.text('Confirmar'));
    await tester.pumpAndSettle();
    expect(servico.gravacoes.single.$2['pagamentoSelecionado'], 5);
  });
}
