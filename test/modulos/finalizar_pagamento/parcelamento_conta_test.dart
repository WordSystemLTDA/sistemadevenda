import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/modelo_datas_vendas.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_parcelamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cardapio/finalizacao_carrinhos_test.dart';

class _ApiTeste extends Fake implements DioCliente {
  @override
  final cliente = Dio();
}

class _DeliveryContaTeste extends ServicoDelivery {
  _DeliveryContaTeste(super.dio, super.usuario);

  String? vencimento;
  List<ParcelasModelo> parcelas = const [];
  int pagamentos = 0;
  int conclusoes = 0;

  final pedidoTeste = PedidoDelivery.fromMap({
    'id': '10118',
    'idCliente': '209',
    'status': 'Pendente',
    'valorVenda': '75.00',
    'somaValorHistorico': '0',
    'tipodeentrega': '2',
  });

  @override
  Future<PedidoDelivery> pedido(String id) async => pedidoTeste;

  @override
  Future<void> pagar(
    PedidoDelivery pedido,
    int forma,
    double recebido, {
    double? valorOriginal,
    double? valorAPagar,
    double? desconto,
    double? acrescimo,
    String? dataLancamento,
    List<ParcelasModelo> parcelasLista = const [],
  }) async {
    expect(forma, 2);
    expect(recebido, 75);
    vencimento = dataLancamento;
    parcelas = parcelasLista;
    pagamentos++;
  }

  @override
  Future<void> concluir(PedidoDelivery pedido) async {
    conclusoes++;
  }
}

class _ModuloContaTeste extends ModuloFinalizacaoTeste {
  late final delivery = _DeliveryContaTeste(api, usuario);

  @override
  void binds(Injector i) {
    super.binds(i);
    i.addInstance<ProvedorBalcao>(ProvedorBalcao(ServicoBalcao(api, usuario)));
    i.addInstance<ServicoDelivery>(delivery);
    i.addInstance<ServicoFinalizarPagamento>(
        ServicoFinalizarPagamento(api, usuario));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('normaliza os prazos configurados no banco sem deixar dias vazios', () {
    final configurado = ModeloDatasVendas.fromMap({
      'vendaDia1': '7',
      'vendaDia2': 14,
      'vendaDia3': ' 21 ',
      'vendaDia4': '28',
    });
    expect(
      [
        configurado.vendaDia1,
        configurado.vendaDia2,
        configurado.vendaDia3,
        configurado.vendaDia4,
      ],
      ['7', '14', '21', '28'],
    );

    final incompleto = ModeloDatasVendas.fromMap({
      'vendaDia1': '',
      'vendaDia2': null,
      'vendaDia3': 'invalido',
      'vendaDia4': '-1',
    });
    expect(
      [
        incompleto.vendaDia1,
        incompleto.vendaDia2,
        incompleto.vendaDia3,
        incompleto.vendaDia4,
      ],
      ['30', '45', '60', '90'],
    );
  });

  test('consulta os prazos atuais da empresa sem usar resposta antiga',
      () async {
    final api = _ApiTeste();
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(empresa: '32', id: '1'));
    RequestOptions? requisicao;
    api.cliente.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        requisicao = options;
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {
            'vendaDia1': '10',
            'vendaDia2': '20',
            'vendaDia3': '30',
            'vendaDia4': '40',
          },
        ));
      },
    ));

    final prazos =
        await ServicoFinalizarPagamento(api, usuario).listarDatasVendas();

    expect(requisicao?.path, '/tela_nfe_saida/listar_datas_vendas.php');
    expect(requisicao?.queryParameters['empresa'], '32');
    expect(requisicao?.extra['semCache'], isTrue);
    expect(prazos?.vendaDia1, '10');
    expect(prazos?.vendaDia4, '40');
    api.cliente.close();
  });

  test('pagamento em conta do delivery envia vencimentos e parcelas', () async {
    SharedPreferences.setMockInitialValues({});
    final api = _ApiTeste();
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(empresa: '32', id: '1'));
    Map<String, dynamic>? pagamento;
    api.cliente.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        pagamento = Map<String, dynamic>.from(
            jsonDecode(options.data as String) as Map);
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'sucesso': true, 'mensagem': 'Ok'},
        ));
      },
    ));

    final pedido = PedidoDelivery.fromMap({
      'id': '10118',
      'idCliente': '209',
      'status': 'Pendente',
      'valorVenda': '75.00',
      'somaValorHistorico': '0',
      'tipodeentrega': '2',
    });
    final parcelas = [
      ParcelasModelo(parcela: '1', valor: '37.50', vencimento: '2026-10-19'),
      ParcelasModelo(parcela: '2', valor: '37.50', vencimento: '2026-11-19'),
    ];

    await ServicoDelivery(api, usuario).pagar(
      pedido,
      2,
      75,
      valorOriginal: 75,
      valorAPagar: 75,
      dataLancamento: '2026-10-19',
      parcelasLista: parcelas,
    );

    expect(pagamento?['pagamentoSelecionado'], 2);
    expect(pagamento?['dataLancamento'], '2026-10-19');
    expect(pagamento?['parcelas'], '2');
    final enviadas = (pagamento?['parcelasLista'] as List)
        .map((item) => jsonDecode(item as String) as Map<String, dynamic>)
        .toList();
    expect(enviadas, [
      {'parcela': '1', 'valor': '37.50', 'vencimento': '2026-10-19'},
      {'parcela': '2', 'valor': '37.50', 'vencimento': '2026-11-19'},
    ]);
    api.cliente.close();
  });

  testWidgets('tela usa os prazos do banco e finaliza a conta no delivery',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(943, 2048);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final modulo = _ModuloContaTeste();
    modulo.cardapio
      ..tipo = TipoCardapio.delivery
      ..idCliente = '209'
      ..tipodeentrega = '2';
    Modular.init(modulo);
    Modular.get<ProvedorFinalizarPagamento>().idVenda = '10118';
    addTearDown(() {
      modulo.servidor.dispose();
      modulo.carrinho.dispose();
      modulo.recorrentes.dispose();
      modulo.cardapio.dispose();
      modulo.usuario.dispose();
      modulo.api.cliente.close();
      Modular.destroy();
    });

    await tester.pumpWidget(const MaterialApp(
      home: PaginaParcelamento(
        idVenda: '10118',
        valor: 75,
        acrescimo: '0',
        desconto: '0',
        descontoPercentual: '0',
        totalPedido: '75.00',
        totalReceber: '75.00',
        valorFalta: '0',
        valorTroco: '0',
        pagamentoselecionado: '2',
      ),
    ));
    await tester.pumpAndSettle();

    for (final prazo in ['30 dias', '45 dias', '60 dias', '90 dias']) {
      expect(find.text(prazo), findsOneWidget);
    }

    final hoje = DateUtils.dateOnly(DateTime.now());
    final primeiroVencimento = hoje.add(const Duration(days: 30));
    expect(
      find.text(DateFormat('dd/MM/yyyy').format(primeiroVencimento)),
      findsNWidgets(2),
    );

    await tester.tap(find.text('Adicionar'));
    await tester.pump();
    await tester.tap(find.text('45 dias'));
    await tester.pump();

    final vencimentoEm45Dias = hoje.add(const Duration(days: 45));
    final vencimentoEm75Dias = hoje.add(const Duration(days: 75));
    expect(
      find.text(DateFormat('dd/MM/yyyy').format(vencimentoEm45Dias)),
      findsNWidgets(2),
    );
    expect(
      find.text(DateFormat('dd/MM/yyyy').format(vencimentoEm75Dias)),
      findsOneWidget,
    );

    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(modulo.delivery.pagamentos, 1);
    expect(modulo.delivery.conclusoes, 1);
    expect(
      modulo.delivery.vencimento,
      DateFormat('yyyy-MM-dd').format(vencimentoEm45Dias),
    );
    expect(modulo.delivery.parcelas, hasLength(2));
    expect(
      modulo.delivery.parcelas.map((parcela) => parcela.vencimento).toList(),
      [
        DateFormat('yyyy-MM-dd').format(vencimentoEm45Dias),
        DateFormat('yyyy-MM-dd').format(vencimentoEm75Dias),
      ],
    );
    expect(
      modulo.delivery.parcelas
          .map((parcela) => parcela.valorController?.text)
          .toList(),
      ['37.50', '37.50'],
    );
    expect(tester.takeException(), isNull);
  });
}
