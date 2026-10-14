import 'dart:convert';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/balcao/modelos/informacoes_retorno_modelo.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_lista_financeiro_venda.dart';
import 'package:app/src/modulos/balcao/modelos/modelo_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/modelos/retorno_listar_por_id_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_forma_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_parcelamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../essencial/utils/impressao_preparo_test.dart' show produto;
import '../cardapio/finalizacao_carrinhos_test.dart';

class _InformacoesTeste extends Fake implements InformacoesRetornoModelo {
  @override
  String get valorentrega => '0';
  @override
  String get subtotal => '10.00';
  @override
  String get docempresa => '';
  @override
  String get celularcliente => '';
  @override
  String get enderecoempresa => '';
  @override
  String get tipodeentrega => '2';
  @override
  String get nomeCliente => 'Cliente teste';
}

class _BalcaoTeste extends Fake implements ServicoBalcao {
  @override
  Future<List<ModeloVendasBalcao>> listar(
          int pagina,
          int linhasPorPagina,
          String pesquisa,
          String dataInicio,
          String dataFim,
          String hora) async =>
      [
        ModeloVendasBalcao(
          id: '138',
          nomecliente: 'Cliente teste',
          numeropedido: '0',
          quantidadeProdutos: '1',
          pagamento: 'Dinheiro',
          subtotal: '10.00',
          status: 'Finalizado',
          nomeusuariocompleto: 'Garcom',
          nomeusuario: 'Garcom',
          dataHora: DateTime.now().toIso8601String(),
          valorTotalF: '10.00',
          tamanhoLista: 1,
          idtipodeentrega: '2',
          tipodeentrega: 'Retirada',
          nomeEmpresa: 'Restaurante teste',
        ),
      ];

  @override
  Future<RetornoListarPorIdBalcao> listarPorId(String idVenda) async =>
      RetornoListarPorIdBalcao(
        produtos: [produto(computador: 'Bar')],
        informacoes: _InformacoesTeste(),
      );

  @override
  Future<List<Modelolistafinanceirovenda>> listarFinanceiroVenda(
          String idVenda) async =>
      [
        Modelolistafinanceirovenda(
          descricaoMov: '',
          documentoMov: '',
          entradaMov: 'Dinheiro',
          vencimentoMovF: '',
          valorMovF: '10,00',
          statusMov: 'Recebido',
        ),
      ];
}

class _ModuloTeste extends ModuloFinalizacaoTeste {
  final servicoBalcao = _BalcaoTeste();
  late final balcao = ProvedorBalcao(servicoBalcao);

  @override
  void binds(Injector i) {
    super.binds(i);
    i.addInstance<ProvedorBalcao>(balcao);
    i.addInstance<ServicoBalcao>(servicoBalcao);
    i.addInstance<ServicoFinalizarPagamento>(
        ServicoFinalizarPagamento(api, usuario));
  }
}

void main() {
  for (final parcelado in [false, true]) {
    for (final preparoUnido in [false, true]) {
      testWidgets(
          'balcão ${parcelado ? 'parcelado' : 'à vista'} imprime sem número com preparo ${preparoUnido ? 'unido' : 'separado'}',
          (tester) async {
        SharedPreferences.setMockInitialValues({
          'conexao': jsonEncode(
              {'tipoConexao': 'local', 'servidor': 'Cozinha', 'porta': '9980'})
        });
        tester.view.physicalSize = const Size(800, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final modulo = _ModuloTeste();
        var pagamentos = 0;
        modulo.api.cliente.interceptors.insert(0,
            InterceptorsWrapper(onRequest: (options, handler) {
          Object? dados;
          if (options.path.endsWith('balcao/pagar_pedido.php')) {
            pagamentos++;
            dados = {
              'sucesso': true,
              'mensagem': 'Ok',
              'idVenda': '138',
              'numeroPedido': '0',
            };
          } else if (options.path.contains('config_bigchef/listar.php')) {
            dados = {
              'imprimirpreparocomprovanteconsumacao':
                  preparoUnido ? 'Sim' : 'Não'
            };
          }
          if (dados != null) {
            handler.resolve(Response(requestOptions: options, data: dados));
          } else {
            handler.next(options);
          }
        }));
        app.usuarioProvedor = modulo.usuario;
        Modular.init(modulo);
        var servidorEncerrado = false;
        addTearDown(() {
          if (!servidorEncerrado) modulo.servidor.dispose();
          modulo.carrinho.dispose();
          modulo.recorrentes.dispose();
          modulo.cardapio.dispose();
          modulo.balcao.dispose();
          modulo.usuario.dispose();
          modulo.api.cliente.close();
          Modular.destroy();
        });
        await modulo.selecionar('138', tipo: TipoCardapio.balcao);
        modulo.cardapio.tipo = TipoCardapio.balcao;
        await modulo.adicionar('Produto balcão', '1010');
        Modular.get<ProvedorFinalizarPagamento>().idVenda = '138';

        final Widget pagina = parcelado
            ? const PaginaParcelamento(
                idVenda: '138',
                valor: 10,
                acrescimo: '0',
                desconto: '0',
                descontoPercentual: '0',
                totalPedido: '10.00',
                totalReceber: '10.00',
                valorFalta: '0',
                valorTroco: '0',
                pagamentoselecionado: '2',
              )
            : const PaginaFinalizarFormaPagamento(
                totalReceber: 10,
                desconto: 0,
                acrescimo: '0',
                descontoPercentual: '0',
                totalPedido: '10.00',
                pagamentoselecionado: '1',
                nomePagamentoSelecionado: 'Dinheiro',
              );
        await tester.pumpWidget(MaterialApp(
          initialRoute: 'PaginaBalcao',
          routes: {
            '/': (_) => const SizedBox.shrink(),
            'PaginaBalcao': (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(builder: (_) => pagina),
                    ),
                    child: const Text('Pagar venda'),
                  ),
                ),
          },
        ));
        await tester.tap(find.text('Pagar venda'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Finalizar'));
        await tester.pumpAndSettle();

        expect(pagamentos, 1);
        final preparos = modulo.servidor.mensagens
            .where((mensagem) => mensagem['tipoImpressao'] == '1');
        final consumos = modulo.servidor.mensagens
            .where((mensagem) => mensagem['tipoImpressao'] == '2');
        expect(preparos, hasLength(preparoUnido ? 0 : 1));
        expect(consumos, hasLength(1));
        for (final mensagem in [...preparos, ...consumos]) {
          expect(mensagem['numeroPedido'], '');
          expect(mensagem['comanda'], 'Balcão 138');
          expect(mensagem['tipo'], TipoCardapio.balcao.nome);
          expect(mensagem['protocoloImpressao'], 2);
        }
        expect(find.text('Pagar venda'), findsOneWidget);
        expect(tester.takeException(), isNull);
        modulo.servidor.dispose();
        servidorEncerrado = true;
      });
    }
  }
}
