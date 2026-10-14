import 'dart:async';
import 'dart:convert';

import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../essencial/utils/impressao_preparo_test.dart' as impressao;
import 'delivery_test.dart';

class _ServicoSemResposta extends ServicoDeliveryTeste {
  int consultasPedido = 0, consultasImpressao = 0, consultasConfiguracao = 0;
  final _pedidoRemoto = Completer<PedidoDelivery>();
  final _impressaoRemota = Completer<Modeloworddadoscardapio>();

  @override
  Future<PedidoDelivery> pedido(String id) {
    consultasPedido++;
    return _pedidoRemoto.future;
  }

  @override
  Future<ConfigDelivery> configuracao() {
    consultasConfiguracao++;
    return super.configuracao();
  }

  @override
  Future<Modeloworddadoscardapio> dadosCardapio(String id) {
    consultasImpressao++;
    return _impressaoRemota.future;
  }
}

class _ServicoEtapaLocal extends _ServicoSemResposta {
  @override
  Future<PedidoDelivery> pedidoParaOperacao(PedidoDelivery snapshot) async =>
      atual;

  @override
  Future<Map<String, dynamic>> avancar(
      PedidoDelivery pedido, EtapaDelivery destino,
      {String entregador = '',
      String valorEntrega = '0',
      List<String> impressoes = const []}) async {
    gravacoes.add(('etapa-local', {'id': pedido.id, 'impressoes': impressoes}));
    atual = pedido.comEtapa(destino.id);
    return {'sucesso': true, 'salvo_no_aparelho': true, 'pedido': atual.dados};
  }
}

List<EtapaDelivery> _etapas(PedidoDelivery pedido) => [
      for (final (id, nome, botao, impressao) in [
        ('1', 'AGUARDANDO', 'PREPARAR', '0'),
        ('2', 'PREPARANDO', 'DESPACHAR', '1'),
        ('3', 'TRÂNSITO', 'ENTREGUE', '2'),
      ])
        EtapaDelivery.fromMap({
          'id': id,
          'nomeOpcao': nome,
          'nomeBotao': botao,
          'tipodeimpressao': impressao,
          'vendas': pedido.etapa == id ? [pedido.dados] : [],
        }),
    ];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final numero in ['', '0', '-1', 'Local ABC123']) {
    test('comprovante sem numero oficial permite operacao: $numero', () {
      final mensagens = ImpressaoDelivery.comprovantes(
          ServicoDeliveryTeste(),
          pedidoTeste(campos: {'numeroPedido': numero}),
          [impressao.produto(computador: 'COZINHA')]);
      final mensagem = jsonDecode(mensagens.single) as Map;
      expect(mensagem['numeroPedido'], '');
      expect(mensagem['comanda'], 'Delivery 25');
      expect(mensagem['nomeCliente'], 'Bruno Masson');
      expect(mensagem['produtos'], hasLength(1));
    });
  }

  test('preparo usa destino e montagem salvos sem consultar o servidor',
      () async {
    final servidor = impressao.ServidorTeste();
    Modular.init(impressao.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final local = impressao.produto(computador: 'COZINHA')
      ..observacao = 'Sem cebola';
    final servico = _ServicoSemResposta()..produtosLocais = [local];
    final pedido = pedidoTeste(campos: {
      'numeroPedido': '0',
      'produtos': [impressao.produto().toMap()],
    });

    final mensagens = await ImpressaoDelivery.prepararMensagens(servico, pedido,
        preparo: true,
        usarDadosDoPedido: true,
        config: const ConfigDelivery(imprimirPreparo: true));

    final mensagem = jsonDecode(mensagens.single) as Map;
    expect(mensagem['numeroPedido'], '');
    expect(mensagem['nomedopc'], 'COZINHA');
    expect(((mensagem['produtos'] as List).single as Map)['observacao'],
        'Sem cebola');
    expect(servico.consultasImpressao, 0);
    expect(servico.consultasConfiguracao, 0);
  });

  for (final local in [false, true]) {
    testWidgets('PREPARAR avanca sem esperar servidor; pedido local: $local',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final servidor = impressao.ServidorTeste();
      Modular.init(impressao.ModuloImpressaoTeste(servidor));
      addTearDown(Modular.destroy);
      final servico = local ? _ServicoEtapaLocal() : _ServicoSemResposta();
      servico.config =
          const ConfigDelivery(receberNoFinal: true, imprimirPreparo: true);
      servico.atual = pedidoTeste(campos: {
        if (local) 'id': 'delivery-local:teste',
        if (local) 'faseLocal': 'enfileirado',
        if (local) 'estadoSincronizacao': 'pendente',
        'numeroPedido': '0',
        'somaValorHistorico': '86.00',
        'produtos': [impressao.produto(computador: 'COZINHA').toMap()],
      });
      servico.respostaLista = () async => _etapas(servico.atual);
      final provedor = ProvedorDelivery(servico);
      addTearDown(provedor.dispose);
      await tester
          .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
      await tester.pumpAndSettle();
      final configuracoesAntes = servico.consultasConfiguracao;

      await tester.tap(find.text('PREPARAR'));
      await tester.pumpAndSettle();

      expect(servico.gravacoes, hasLength(1));
      expect(servico.atual.etapa, '2');
      expect(servico.consultasPedido, 0);
      expect(servico.consultasImpressao, 0);
      // Uma atualização de configuração pode ocorrer em segundo plano,
      // mas a ação usa a configuração que já estava disponível na tela.
      expect(servico.consultasConfiguracao - configuracoesAntes,
          lessThanOrEqualTo(1));
      expect(find.text('Aguarde o servidor'), findsNothing);
      expect(find.text('PREPARANDO (1)'), findsOneWidget);
      final mensagens = local
          ? (servico.gravacoes.single.$2['impressoes'] as List)
              .map((m) => jsonDecode(m as String) as Map)
              .toList()
          : servidor.mensagens;
      expect(mensagens.single['numeroPedido'], '');
      expect(mensagens.single['nomedopc'], 'COZINHA');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
