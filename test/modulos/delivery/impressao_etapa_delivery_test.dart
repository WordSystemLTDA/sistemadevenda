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
import 'delivery_test.dart';

class _ServicoFalha extends ServicoDeliveryTeste {
  @override
  Future<Modeloworddadoscardapio> dadosCardapio(String id) async =>
      throw StateError('Dados indisponiveis');
}

class _ServicoPix extends ServicoDeliveryTeste {
  final enviosPix = <Map<String, dynamic>>[];
  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'delivery/notificarenviarchavepix.php') {
      enviosPix.add(campos);
      return {'sucesso': true};
    }
    return super.consultar(rota, campos);
  }
}

void main() {
  for (final enviarPix in [false, true]) {
    testWidgets('concluir controla envio Pix e retentativa: $enviarPix',
        (tester) async {
      final servico = _ServicoPix();
      if (enviarPix) {
        await servico.concluir(servico.atual);
      } else {
        await servico.concluir(servico.atual, enviarChavePix: false);
      }
      expect(servico.gravacoes.single.$2['enviarChavePix'], enviarPix);
      await tester.pump(const Duration(seconds: 31));
      expect(servico.enviosPix, hasLength(enviarPix ? 1 : 0));
      if (enviarPix) expect(servico.enviosPix.single['automatico'], '1');
    });
  }

  testWidgets('de transito para entregue conclui e avanca sem enviar Pix',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final servico = _ServicoPix()
      ..atual = pedidoTeste(campos: {
        'id': '3',
        'idopcoescarrossel': '3',
        'somaValorHistorico': '86.00'
      });
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await tester
        .pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Em entrega (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('avancar-delivery-3')));
    await tester.pumpAndSettle();
    final finalizacao = servico.gravacoes
        .where((r) => r.$1 == 'delivery/finalizar_pedido_delivery.php');
    expect(finalizacao, hasLength(1));
    expect(finalizacao.single.$2['enviarChavePix'], isFalse);
    expect(
        servico.gravacoes
            .where((r) => r.$1 == 'delivery/mudar_status_delivery.php')
            .single
            .$2['status'],
        '4');
    await tester.pump(const Duration(seconds: 31));
    expect(servico.enviosPix, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('falha ao preparar impressao impede mudanca de etapa', (tester) async {
    final servico = _ServicoFalha()..config = const ConfigDelivery(receberNoFinal: true, imprimirPreparo: true);
    final provedor = ProvedorDelivery(servico);
    addTearDown(provedor.dispose);
    await tester.pumpWidget(MaterialApp(home: PaginaDelivery(provedor: provedor)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Iniciar preparo').first);
    await tester.pumpAndSettle();
    expect(servico.gravacoes, isEmpty);
    expect(find.text('Dados indisponiveis'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('envia etapa e mensagens com os mesmos IDs preparados antes da gravacao', () async {
    final servidor = impressao.ServidorTeste();
    Modular.init(impressao.ModuloImpressaoTeste(servidor));
    addTearDown(Modular.destroy);
    final servico = ServicoDeliveryTeste()..produtosCardapio = [impressao.produto(computador: 'COZINHA')];
    final mensagens = await ImpressaoDelivery.prepararMensagens(servico, servico.atual, preparo: true);
    expect(servidor.mensagens, isEmpty);
    expect(mensagens, isNotEmpty);
    await servico.avancar(servico.atual, etapasTeste()[1], impressoes: mensagens);
    expect(servico.gravacoes.single.$2['impressoes'], mensagens);
    expect(servico.gravacoes.single.$2['tipoImpressaoEsperado'],
        etapasTeste()[1].impressao);
    await ImpressaoDelivery.enviarPreparadas(servidor, mensagens);
    expect(servidor.mensagens.single['idRequisicao'], (jsonDecode(mensagens.single) as Map)['idRequisicao']);
  });

  test('persistencia confirmada deixa cozinha na API e encaminha outros comprovantes', () async {
    final servidor = impressao.ServidorTeste();
    final preparo = jsonEncode({'idRequisicao': 'cozinha-1', 'tipoImpressao': '1'});
    final comprovante = jsonEncode({'idRequisicao': 'cliente-1', 'tipoImpressao': '2'});
    await ImpressaoDelivery.enviarPreparadas(servidor, [preparo, comprovante], preparoPersistido: true);
    expect(servidor.mensagens.where((m) => m['tipoImpressao'] == '1'), isEmpty);
    expect(servidor.mensagens.where((m) => m['tipo'] == 'PreparoPendente'), hasLength(1));
    expect(servidor.mensagens.where((m) => m['idRequisicao'] == 'cliente-1'), hasLength(1));
  });
}
