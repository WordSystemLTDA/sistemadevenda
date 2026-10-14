import 'dart:convert';

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

class _ServicoPreparo extends ServicoDeliveryTeste {
  final bool preparoNaApi;
  _ServicoPreparo(this.preparoNaApi);

  @override
  Future<Map<String, dynamic>> salvar(
      String rota, Map<String, dynamic> campos) async {
    final resposta = await super.salvar(rota, campos);
    return {
      ...resposta,
      if (rota == 'delivery/mudar_status_delivery.php')
        'impressao_persistida': preparoNaApi,
    };
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final numero in ['0', '', '-1']) {
    test(
        'preparo e entregador sem numero oficial preservam atendimento: $numero',
        () async {
      final servidor = impressao.ServidorTeste();
      Modular.init(impressao.ModuloImpressaoTeste(servidor));
      addTearDown(Modular.destroy);
      final servico = ServicoDeliveryTeste()
        ..numeroPedidoCardapio = numero
        ..produtosCardapio = [
          impressao.produto(computador: 'COZINHA')..observacao = 'Sem cebola',
        ];

      await ImpressaoDelivery.imprimir(
          servico, servidor, pedidoTeste(campos: {'numeroPedido': numero}),
          ambos: true,
          config: const ConfigDelivery(
            imprimirPreparo: true,
            ativarnumerooperacionalpedido: 'Não',
          ));

      expect(servidor.mensagens, hasLength(2));
      expect(servidor.mensagens.map((m) => m['tipoImpressao']), ['1', '3']);
      for (final mensagem in servidor.mensagens) {
        expect(mensagem['numeroPedido'], '');
        expect(mensagem['comanda'], 'Delivery 25');
        expect(mensagem['nomeCliente'], 'Bruno Masson');
        expect(mensagem['nomedopc'], 'COZINHA');
        expect(mensagem['ativarnumerooperacionalpedido'], 'Não');
        expect(mensagem['idRequisicao'], isNotEmpty);
      }
    });
  }

  for (final caso in [
    (unificar: false, tipo: '1', persistido: false, tipoImpressao: '1'),
    (unificar: false, tipo: '1', persistido: true, tipoImpressao: '1'),
    (unificar: true, tipo: '1', persistido: false, tipoImpressao: '3'),
    (unificar: true, tipo: '2', persistido: false, tipoImpressao: '2'),
  ]) {
    testWidgets('PREPARAR com numero zero usa envio original: $caso',
        (tester) async {
      tester.view.physicalSize = const Size(1000, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final servidor = impressao.ServidorTeste();
      Modular.init(impressao.ModuloImpressaoTeste(servidor));
      addTearDown(Modular.destroy);
      final servico = _ServicoPreparo(caso.persistido)
        ..config = ConfigDelivery(
          receberNoFinal: true,
          imprimirPreparo: true,
          imprimirPreparoNoComprovanteConsumacao: caso.unificar,
        )
        ..numeroPedidoCardapio = '0'
        ..produtosCardapio = [impressao.produto(computador: 'COZINHA')];
      servico.atual = pedidoTeste(campos: {
        'numeroPedido': '0',
        'tipodeentrega': caso.tipo,
        'somaValorHistorico': '86.00',
      });
      servico.respostaLista = () async => [
            for (final (id, nome, botao, tipoImpressao) in [
              ('1', 'AGUARDANDO', 'PREPARAR', '0'),
              ('2', 'PREPARANDO', 'PRONTO', '1'),
            ])
              EtapaDelivery.fromMap({
                'id': id,
                'nomeOpcao': nome,
                'nomeBotao': botao,
                'tipodeimpressao': tipoImpressao,
                'vendas':
                    servico.atual.etapa == id ? [servico.atual.dados] : [],
              }),
          ];
      final provedor = ProvedorDelivery(servico);
      addTearDown(provedor.dispose);
      await tester
          .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('PREPARAR'));
      await tester.pumpAndSettle();

      expect(servico.gravacoes, hasLength(1));
      final (rota, campos) = servico.gravacoes.single;
      expect(rota, 'delivery/mudar_status_delivery.php');
      expect(campos['status'], '2');
      expect(servico.atual.etapa, '2');
      final preparada =
          jsonDecode((campos['impressoes'] as List).single as String) as Map;
      expect(preparada['numeroPedido'], '');
      expect(preparada['tipoImpressao'], caso.tipoImpressao);
      if (caso.persistido) {
        expect(servidor.mensagens.where((m) => m['tipoImpressao'] == '1'),
            isEmpty);
        expect(servidor.mensagens.single['tipo'], 'PreparoPendente');
      } else {
        expect(servidor.mensagens, hasLength(1));
        expect(servidor.mensagens.single['idRequisicao'],
            preparada['idRequisicao']);
        expect(servidor.mensagens.single['tipoImpressao'], caso.tipoImpressao);
      }
      expect(find.textContaining('Aguarde o servidor'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
