import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _AdaptadorPagamento implements HttpClientAdapter {
  final chamadas = <RequestOptions>[];
  final bool perderPrimeiraResposta;
  final String resposta;

  _AdaptadorPagamento({
    this.perderPrimeiraResposta = false,
    this.resposta = '{"sucesso":true,"mensagem":"ok","finalizouPedido":"0",'
        '"idVenda":"0","somaValorHistorico":"6.00"}',
  });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    if (perderPrimeiraResposta && chamadas.length == 1) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.receiveTimeout,
      );
    }
    return ResponseBody.fromString(
      resposta,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Modelowordprodutos _produto() => Modelowordprodutos(
      id: '100',
      iditensvenda: '77',
      nome: 'Água',
      codigo: '100',
      estoque: '0',
      tamanho: '',
      foto: '',
      ativo: 'Sim',
      descricao: '',
      valorVenda: '6.00',
      valorTotalVendas: '6.00',
      valorPago: '0',
      categoria: '1',
      nomeCategoria: 'Bebidas',
      habilTipo: '',
      ingredientes: const [],
      quantidade: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('envia pagamento parcial para o endpoint correto da comanda', () async {
    final api = DioCliente(servidor: 'https://servidor.test/api1/');
    addTearDown(() => api.cliente.close());
    final adaptador = _AdaptadorPagamento();
    api.cliente.httpClientAdapter = adaptador;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '7', empresa: '9', nome: 'Operador'));
    addTearDown(usuario.dispose);
    final servico = ServicoFinalizarPagamento(api, usuario);

    final resultado = await servico.pagarContaAtendimento(
      id: '138',
      idComanda: '3',
      idMesa: '0',
      cliente: '2',
      tipo: TipoCardapio.comanda,
      valorLancamento: 6,
      valorOriginal: 18,
      valorAPagar: 6,
      troco: 0,
      pagamentoSelecionado: 5,
      quantidadePessoas: 1,
      vencimento: DateTime(2026, 9, 21),
      produtosParaFinalizar: [_produto()],
      modoProdutoParcial: true,
    );

    expect(resultado.sucesso, isTrue);
    expect(resultado.finalizou, isFalse);
    expect(adaptador.chamadas, hasLength(1));
    final chamada = adaptador.chamadas.single;
    expect(chamada.uri.path, '/api1/comandas/pagar_pedido.php');
    final corpo = jsonDecode(chamada.data as String) as Map<String, dynamic>;
    expect(corpo['empresa'], '9');
    expect(corpo['tipo'], 'Comanda');
    expect(corpo['id_operacao'], matches(RegExp(r'^[a-f0-9]{48}$')));
    expect(corpo['modoProdutoParcial'], isTrue);
    expect(corpo['valor_lancamento'], '6.00');
    expect(corpo['produtosParaFinalizar'], hasLength(1));
    expect(corpo['produtosParaFinalizar'][0]['iditensvenda'], '77');
    expect(corpo['produtosParaFinalizar'][0]['valorpago'], '0');
  });

  test('resposta perdida repete o mesmo recibo sem duplicar o pagamento',
      () async {
    final api = DioCliente(servidor: 'https://servidor.test/api1/');
    addTearDown(() => api.cliente.close());
    final adaptador = _AdaptadorPagamento(perderPrimeiraResposta: true);
    api.cliente.httpClientAdapter = adaptador;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '7', empresa: '9', nome: 'Operador'));
    addTearDown(usuario.dispose);
    final servico = ServicoFinalizarPagamento(api, usuario);

    final resultado = await servico.pagarContaAtendimento(
      id: '139',
      idComanda: '3',
      idMesa: '0',
      cliente: '2',
      tipo: TipoCardapio.comanda,
      valorLancamento: 6,
      valorOriginal: 18,
      valorAPagar: 6,
      troco: 0,
      pagamentoSelecionado: 1,
      quantidadePessoas: 1,
      vencimento: DateTime(2026, 9, 21),
      produtosParaFinalizar: const [],
      modoProdutoParcial: false,
    );

    expect(resultado.sucesso, isTrue);
    expect(adaptador.chamadas, hasLength(2));
    final primeiro = jsonDecode(adaptador.chamadas.first.data as String) as Map;
    final segundo = jsonDecode(adaptador.chamadas.last.data as String) as Map;
    expect(segundo['id_operacao'], primeiro['id_operacao']);
    expect(segundo, primeiro);
  });

  test('finalizacao do balcao preserva o numero oficial retornado pela API',
      () async {
    final api = DioCliente(servidor: 'https://servidor.test/api1/');
    addTearDown(() => api.cliente.close());
    final adaptador = _AdaptadorPagamento(
      resposta:
          '{"sucesso":true,"mensagem":"ok","idVenda":"901","numeroPedido":"57"}',
    );
    api.cliente.httpClientAdapter = adaptador;
    final usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '7', empresa: '9', nome: 'Operador'));
    addTearDown(usuario.dispose);

    final resultado = await ServicoFinalizarPagamento(api, usuario).pagarPedido(
      '0',
      '0',
      '0',
      '0',
      '12.00',
      '12.00',
      1,
      0,
      '12.00',
      '2026-09-25',
      '0',
      [],
      TipoCardapio.balcao,
      '0.00',
      '0.00',
      '12.00',
      false,
      '3',
      const [],
      '12.00',
      '',
    );

    expect(resultado.sucesso, isTrue);
    expect(resultado.idVenda, '901');
    expect(resultado.numeroPedido, '57');
  });
}
