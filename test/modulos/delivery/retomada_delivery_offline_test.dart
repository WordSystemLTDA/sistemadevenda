import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../cardapio/finalizacao_carrinhos_test.dart';
import '../../suporte/captura_tela.dart';

// A persistencia SQLite/reinicio e exercitada em fila_delivery_offline_test.
// Este teste cobre a navegacao da lista local para o saldo parcial, sem uma
// consulta financeira remota (inclusive a protecao real de recorrencias locais).
class _DeliveryLocal extends ServicoDelivery {
  _DeliveryLocal(super.dio, super.usuario);

  String fase = 'rascunho';
  int confirmacoes = 0;
  int consultasRemotas = 0;
  double? descontoSalvo, acrescimoSalvo;
  static const id = 'delivery-local:teste-retomada';

  Map<String, dynamic> get dados => {
        'id': id,
        'idCliente': '209',
        'idendereco': '2',
        'nomeCliente': 'Cliente offline',
        'tipodeentrega': '1',
        'numeroPedido': 'Local teste',
        'status': 'Pendente',
        'id_etapa': 'local',
        'faseLocal': fase,
        'produtosConfirmadosLocal': true,
        'valorVenda': '50.00',
        'valorDesconto': '6.00',
        'valorAcrescimo': '2.00',
        'somaValorHistorico': '20.00',
        'valordaentrega': '4.00',
        'enderecoCliente': 'Rua Offline',
        'numeroCliente': '15',
        'bairroCliente': 'Centro',
        'cidadeCliente': 'Cidade',
        'produtos': [
          {'id': '1', 'nome': 'Almoço', 'quantidade': 1, 'valorVenda': '50'}
        ],
      };

  @override
  Future<List<EtapaDelivery>> listar({
    required DateTime inicio,
    required DateTime fim,
    required String horaInicio,
    required String horaFim,
    String pesquisa = '',
    String tipo = '0',
  }) async =>
      [
        EtapaDelivery.fromMap({
          'id': 'local',
          'nomeOpcao': 'No aparelho',
          'vendas': [dados],
        })
      ];

  @override
  Future<ConfigDelivery> configuracao() async =>
      const ConfigDelivery(cobrancaEntrega: '1', valorEntrega: '4.00');

  @override
  Future<dynamic> consultar(String rota,
      [Map<String, dynamic> campos = const {}]) async {
    if (rota == 'enderecos_clientes/listar_por_cliente.php') {
      return [
        {
          'id': '2',
          'endereco': 'Rua Offline',
          'numero': '15',
          'bairro': 'Centro',
          'cidade': 'Cidade',
          'padrao': 'Sim',
          'valortaxabairro': '4.00',
        }
      ];
    }
    consultasRemotas++;
    throw StateError('A consulta remota não deve ocorrer para o rascunho.');
  }

  @override
  Future<void> definirAjustesLocais(String id,
      {required double desconto, required double acrescimo}) async {
    expect(id, _DeliveryLocal.id);
    descontoSalvo = desconto;
    acrescimoSalvo = acrescimo;
  }

  @override
  Future<void> confirmar(String id) async {
    expect(id, _DeliveryLocal.id);
    fase = 'enfileirado';
    confirmacoes++;
  }
}

class _ModuloLocal extends ModuloFinalizacaoTeste {
  late final delivery = _DeliveryLocal(api, usuario);
  late final lista = ProvedorDelivery(delivery);

  @override
  void binds(Injector i) {
    super.binds(i);
    i.addInstance<ServicoDelivery>(delivery);
    i.addInstance<ServicoFinalizarPagamento>(
        ServicoFinalizarPagamento(api, usuario));
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);

  testWidgets(
      'retoma Delivery no aparelho pelo saldo parcial e Pagar depois preserva ajustes',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final m = _ModuloLocal();
    m.api.cliente.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (options, handler) {
      if (options.path.startsWith('/tela_nfe_saida/listar_bancos.php')) {
        handler.resolve(Response(requestOptions: options, data: {
          for (final sufixo in [
            'Pix',
            'Opcao2',
            'Opcao3',
            'Opcao4',
            'Opcao5'
          ]) ...{
            'idBanco$sufixo': '0',
            'ativoBanco$sufixo': 'Não',
            'nomeBanco$sufixo': '',
            'pixdinamico${sufixo.toLowerCase()}': 'Não',
          },
        }));
      } else {
        handler.next(options);
      }
    }));
    app.usuarioProvedor = m.usuario;
    Modular.init(m);
    addTearDown(() {
      m.lista.dispose();
      m.servidor.dispose();
      m.carrinho.dispose();
      m.recorrentes.dispose();
      m.cardapio.dispose();
      m.usuario.dispose();
      m.api.cliente.close();
      Modular.destroy();
    });
    await tester.pumpWidget(MaterialApp(
      home: RepaintBoundary(
        key: const ValueKey('captura'),
        child: PaginaDelivery(provedor: m.lista),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('No aparelho (1)'), findsOneWidget);
    expect(find.text('Excluir'), findsOneWidget);
    expect(find.text('Continuar pedido'), findsOneWidget);
    final excluir = tester.getCenter(find.text('Excluir'));
    final continuar = tester.getCenter(find.text('Continuar pedido'));
    expect(excluir.dx, lessThan(continuar.dx));
    expect(excluir.dy, continuar.dy);
    await capturarTela(tester, 'delivery_rascunho_no_aparelho');

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();
    expect(find.text('Excluir rascunho?'), findsOneWidget);
    expect(find.textContaining('não pode ser desfeita'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Continuar pedido'), findsOneWidget);

    await tester.tap(find.text('Continuar pedido'));
    await tester.pumpAndSettle();

    expect(find.byType(PaginaSelecionarPagamento), findsOneWidget);
    final pagina = tester.widget<PaginaSelecionarPagamento>(
        find.byType(PaginaSelecionarPagamento));
    expect(pagina.totalReceber, 30);
    expect(pagina.desconto, 6);
    expect(pagina.acrescimo, '2.00');
    expect(
        Modular.get<ProvedorFinalizarPagamento>().idVenda, _DeliveryLocal.id);
    expect(m.delivery.consultasRemotas, 0);
    expect(find.textContaining('Não foi possível'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('pagar-depois-delivery')));
    await tester.pumpAndSettle();
    expect(m.delivery.confirmacoes, 1);
    expect(m.delivery.descontoSalvo, 6);
    expect(m.delivery.acrescimoSalvo, 2);
    expect(m.delivery.consultasRemotas, 0);
    expect(find.byType(PaginaSelecionarPagamento), findsNothing);
    expect(find.text('Ver sincronização'), findsOneWidget);
    expect(find.text('Excluir'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
}
