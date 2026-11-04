import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../essencial/utils/impressao_preparo_test.dart' as impressao;
import '../../suporte/captura_tela.dart';
import 'delivery_test.dart';

const _avisoEntrega = 'Pagar depois - receber na entrega';
const _avisoMensal = 'Pagar depois - acerto mensal';

class _ServicoRecorrente extends ServicoDeliveryTeste {
  _ServicoRecorrente(
      {bool parcial = false, bool mensal = false, bool receberNoFinal = true}) {
    produtosCardapio = [
      impressao.produto(id: '1', nome: 'Coca Cola 2L', computador: 'CAIXA')
        ..valorVenda = '12.00',
      impressao.produto(id: '3', nome: 'Marmita M', computador: 'CAIXA')
        ..valorVenda = '25.00',
    ];
    atual = pedidoTeste(campos: {
      'id': mensal ? '12' : '7',
      'numeroPedido': mensal ? '12' : '7',
      'recorrenteVinculado': true,
      'pagamentoPendente': true,
      'valorVenda': '40.00',
      'valordaentrega': '3.00',
      'somaValorHistorico': parcial ? '10.00' : '0.00',
      'nomeEmpresa': 'Sistema de Restaurante',
      'cnpjEmpresa': '24.744.723/0001-64',
      'enderecoEmpresa': 'Rua Luiz Roncalha, 169',
      'celularEmpresa': '(44) 99921-3336',
      'produtos': produtosCardapio.map((produto) => produto.toMap()).toList(),
      'lancamentos': [
        if (parcial) {'nome': 'Pix', 'valor': '10.00'},
        {
          'nome': mensal ? _avisoMensal : _avisoEntrega,
          'valor': parcial ? '30.00' : '40.00'
        },
      ],
    });
    config =
        ConfigDelivery(receberNoFinal: receberNoFinal, imprimirPreparo: true);
    respostaLista = () async => [
          for (final (id, nome, botao, tipo) in [
            ('1', 'Aguardando', 'Preparar', '0'),
            ('2', 'Preparando', 'Pronto', '4'),
          ])
            EtapaDelivery.fromMap({
              'id': id,
              'nomeOpcao': nome,
              'nomeBotao': botao,
              'tipodeimpressao': tipo,
              'vendas': atual.etapa == id ? [atual.dados] : [],
            }),
        ];
  }

  @override
  Future<Modeloworddadoscardapio> dadosCardapio(String id) async =>
      Modeloworddadoscardapio(
        id: id,
        numeroPedido: atual.numeroOperacional,
        produtos: produtosCardapio,
      );
}

void _conferirComprovante(Map<String, dynamic> mensagem,
    {bool parcial = false, bool mensal = false}) {
  expect(mensagem['tipoImpressao'], '3');
  expect(mensagem['numeroPedido'], mensal ? '12' : '7');
  expect(mensagem['total'], '40.00');
  expect(mensagem['valorentrega'], '3.00');
  expect(mensagem['somaValorHistorico'], parcial ? '10.00' : '0.00');
  expect(mensagem['nomeCliente'], 'Bruno Masson');
  expect(mensagem['enderecoCliente'], 'Rua das Flores');
  expect(mensagem['numeroCliente'], '123');
  expect(mensagem['nomeEmpresa'], 'Sistema de Restaurante');
  expect(mensagem['cnpjEmpresa'], '24.744.723/0001-64');
  expect((mensagem['produtos'] as List).map((produto) => produto['nome']),
      ['Coca Cola 2L', 'Marmita M']);
  expect(mensagem['nomelancamento'], [
    if (parcial) {'nome': 'Pix', 'valor': '10.00'},
    {
      'nome': mensal ? _avisoMensal : _avisoEntrega,
      'valor': parcial ? '30.00' : '40.00'
    },
  ]);
}

void main() {
  setUpAll(carregarFontesDeTeste);
  tearDown(Modular.destroy);

  for (final parcial in [false, true]) {
    testWidgets('imprimir recorrente na entrega preserva recebimento: $parcial',
        (tester) async {
      final servidor = impressao.ServidorTeste();
      Modular.init(impressao.ModuloImpressaoTeste(servidor));
      final servico = _ServicoRecorrente(parcial: parcial);
      final provedor = ProvedorDelivery(servico);
      addTearDown(provedor.dispose);
      await tester
          .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Opções do pedido #7'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Conta'), 180,
          scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Conta'));
      await tester.pumpAndSettle();

      _conferirComprovante(
          servidor.mensagens
              .singleWhere((mensagem) => mensagem['tipoImpressao'] == '3'),
          parcial: parcial);
      expect(servico.gravacoes, isEmpty);
      expect(servico.atual.pago, parcial ? 10 : 0);
      expect(servico.atual.etapa, '1');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('preparar recorrente imprime cozinha e entregador sem receber',
      (tester) async {
    final servidor = impressao.ServidorTeste();
    Modular.init(impressao.ModuloImpressaoTeste(servidor));
    final servico = _ServicoRecorrente();
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    var recebimentos = 0;
    await tester.pumpWidget(MaterialApp(
      home: PaginaDelivery(
        provedor: provedor,
        receberPedido: (_) async {
          recebimentos++;
          return true;
        },
      ),
    ));
    await tester.pumpAndSettle();
    final botao = find.byKey(const ValueKey('avancar-delivery-7'));
    await tester.ensureVisible(botao);
    await tester.tap(botao);
    await tester.pumpAndSettle();

    expect(recebimentos, 0);
    expect(servico.gravacoes, hasLength(1));
    expect(servico.gravacoes.single.$1, 'delivery/mudar_status_delivery.php');
    expect(servico.gravacoes.single.$2['status'], '2');
    final mensagensGravadas =
        (servico.gravacoes.single.$2['impressoes'] as List)
            .map((mensagem) =>
                jsonDecode(mensagem as String) as Map<String, dynamic>)
            .toList();
    expect(mensagensGravadas.map((mensagem) => mensagem['tipoImpressao']),
        ['1', '3']);
    expect(servidor.mensagens, mensagensGravadas);
    _conferirComprovante(servidor.mensagens.last);
    expect(servico.atual.pago, 0);
    expect(servico.atual.etapa, '2');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final receberNoFinal in [false, true]) {
    for (final parcial in [false, true]) {
      testWidgets(
          'mensal imprime e prepara sem cobrar com receberNoFinal=$receberNoFinal e parcial=$parcial',
          (tester) async {
        final servidor = impressao.ServidorTeste();
        Modular.init(impressao.ModuloImpressaoTeste(servidor));
        final servico = _ServicoRecorrente(
            mensal: true, parcial: parcial, receberNoFinal: receberNoFinal);
        final provedor = ProvedorDelivery(servico);
        addTearDown(provedor.dispose);
        var recebimentos = 0;
        await tester.pumpWidget(MaterialApp(
          home: PaginaDelivery(
            provedor: provedor,
            receberPedido: (_) async {
              recebimentos++;
              return false;
            },
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Opções do pedido #12'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Conta'), 180,
            scrollable: find.byType(Scrollable).last);
        await tester.tap(find.text('Conta'));
        await tester.pumpAndSettle();
        _conferirComprovante(servidor.mensagens.single,
            parcial: parcial, mensal: true);
        expect(servico.gravacoes, isEmpty);
        servidor.mensagens.clear();

        final botao = find.byKey(const ValueKey('avancar-delivery-12'));
        await tester.ensureVisible(botao);
        await tester.tap(botao);
        await tester.pumpAndSettle();
        expect(recebimentos, 0);
        expect(servico.gravacoes, hasLength(1));
        expect(
            servico.gravacoes.single.$1, 'delivery/mudar_status_delivery.php');
        expect(servico.gravacoes.single.$2['status'], '2');
        expect(servidor.mensagens.map((mensagem) => mensagem['tipoImpressao']),
            ['1', '3']);
        _conferirComprovante(servidor.mensagens.last,
            parcial: parcial, mensal: true);
        expect(servico.atual.pago, parcial ? 10 : 0);
        expect(servico.atual.restante, parcial ? 30 : 40);
        expect(servico.atual.etapa, '2');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets(
        'mensal mantém confirmação do acerto na etapa final com receberNoFinal=$receberNoFinal',
        (tester) async {
      final servico =
          _ServicoRecorrente(mensal: true, receberNoFinal: receberNoFinal);
      servico.atual = servico.atual.comEtapa('2');
      servico.respostaLista = () async => [
            for (final (id, nome, botao, tipo) in [
              ('2', 'Preparando', 'Finalizar', '4'),
              ('3', 'Entregue', '', '3'),
            ])
              EtapaDelivery.fromMap({
                'id': id,
                'nomeOpcao': nome,
                'nomeBotao': botao,
                'tipodeimpressao': tipo,
                'vendas':
                    servico.atual.etapa == id ? [servico.atual.dados] : [],
              }),
          ];
      final provedor = ProvedorDelivery(servico);
      addTearDown(provedor.dispose);
      var confirmacoes = 0;
      await tester.pumpWidget(MaterialApp(
        home: PaginaDelivery(
          provedor: provedor,
          receberPedido: (pedido) async {
            confirmacoes++;
            expect(pedido.recorrenteVinculado, isTrue);
            expect(pedido.pagamentoPendente, isTrue);
            expect(pedido.restante, 40);
            expect(pedido.pagamentos.single['nome'], _avisoMensal);
            return false;
          },
        ),
      ));
      await tester.pumpAndSettle();
      final botao = find.byKey(const ValueKey('avancar-delivery-12'));
      await tester.ensureVisible(botao);
      await tester.tap(botao);
      await tester.pumpAndSettle();
      expect(confirmacoes, 1);
      expect(servico.gravacoes, isEmpty);
      expect(servico.atual.pago, 0);
      expect(servico.atual.etapa, '2');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final tipo in ['5', '6']) {
    test('recorrente online pendente $tipo continua sem despacho de impressao',
        () async {
      final servidor = impressao.ServidorTeste();
      final servico = _ServicoRecorrente();
      final pedido = PedidoDelivery.fromMap({
        ...servico.atual.dados,
        'pagamento_online_obrigatorio': true,
        'pagamento_online_tipo': tipo,
        'pagamento_online_status': 'pending',
      });
      await expectLater(
          ImpressaoDelivery.imprimir(servico, servidor, pedido, ambos: true),
          throwsStateError);
      expect(servidor.mensagens, isEmpty);
      expect(servico.gravacoes, isEmpty);
    });
  }
}
