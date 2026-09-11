import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/finalizacao_com_preparo.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/servicos/servicos_itens_recorrentes.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'card_carrinho_test.dart' show produtoCarrinho;
import 'montagem_pizza_test.dart'
    show ModuloTeste, CategoriasTeste, ProdutosTeste;

class ApiCarrinhoTeste extends Fake implements DioCliente {
  @override
  final cliente = Dio();
  Object resposta = <dynamic>[];
  String status = 'Andamento';
  bool falhar = false;
  final chamadas = <RequestOptions>[];

  ApiCarrinhoTeste() {
    cliente.interceptors.add(InterceptorsWrapper(onRequest: (opcoes, handler) {
      chamadas.add(opcoes);
      if (falhar) {
        handler.reject(DioException(
            requestOptions: opcoes, type: DioExceptionType.receiveTimeout));
      } else {
        handler.resolve(Response(
            requestOptions: opcoes,
            statusCode: 200,
            data: opcoes.path.startsWith('cardapio/listar_por_id.php') ||
                    opcoes.path
                        .startsWith('itens_recorrentes/listar_por_id.php')
                ? {'id': opcoes.uri.queryParameters['id'], 'status': status}
                : resposta));
      }
    }));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late UsuarioProvedor usuario;
  late ApiCarrinhoTeste api;
  late ServicosItensComanda servico;
  late ProvedorCarrinho carrinho;
  late ProvedorItensRecorrentes recorrentes;
  final armazenamento = ArmazenamentoCarrinhos.instancia;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(empresa: '32', id: '1'));
    api = ApiCarrinhoTeste();
    servico = ServicosItensComanda(api, usuario);
    carrinho = ProvedorCarrinho(servico);
    recorrentes = ProvedorItensRecorrentes(servico);
  });

  tearDown(() {
    carrinho.dispose();
    recorrentes.dispose();
    usuario.dispose();
    api.cliente.close();
  });

  Future<void> abrir(String numero, String atendimento,
      {String tipo = 'comanda'}) async {
    await carrinho.selecionarAtendimento(
        tipo: tipo, idAtendimento: atendimento, idRecurso: numero);
    recorrentes.selecionarAtendimento(
        tipo: tipo, idAtendimento: atendimento, idRecurso: numero);
    await recorrentes.listarComandasPedidos(atendimento);
  }

  Future<bool> adicionar({Modelowordprodutos? produto}) {
    final item = produto ?? produtoCarrinho();
    return carrinho.inserir(
        item,
        'Comanda',
        '0',
        carrinho.contexto!.idRecurso,
        item.valorVenda,
        '',
        item.id,
        item.nome,
        item.quantidade,
        item.observacao);
  }

  test('comanda 4 conserva duas cocas ao visitar a 6 e reiniciar o aplicativo',
      () async {
    await abrir('4', '104');
    await adicionar();
    await adicionar();
    await abrir('6', '106');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(carrinho.quantidadeDoProduto('1010'), 0);
    await adicionar(
        produto: produtoCarrinho()
          ..nome = 'Agua'
          ..id = '1020');
    await abrir('4', '104');
    expect(carrinho.quantidadeDoProduto('1010'), 2);
    expect(carrinho.itensCarrinho.precoTotal, 20);

    final prefs = await SharedPreferences.getInstance();
    final salvo = prefs.getString(ArmazenamentoCarrinhos.chavePreferencias)!;
    carrinho.dispose();
    SharedPreferences.setMockInitialValues(
        {ArmazenamentoCarrinhos.chavePreferencias: salvo});
    carrinho = ProvedorCarrinho(servico);
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.quantidadeTotal, 2);
    await abrir('6', '106');
    expect(carrinho.itensCarrinho.listaComandosPedidos.single.nome, 'Agua');
  });

  test('edicao, lixeira e limpar afetam somente o atendimento selecionado',
      () async {
    await abrir('4', '104');
    await adicionar();
    await abrir('6', '106');
    await adicionar();
    await carrinho.editar(produtoCarrinho(quantidade: 3), 0);
    expect(carrinho.itensCarrinho.quantidadeTotal, 3);
    await carrinho.excluirItemCarrinho('1010', 0);
    await adicionar();
    await carrinho.removerComandasPedidos();
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
  });

  test('retorno de inclusao de outra comanda nao entra no carrinho atual',
      () async {
    await abrir('6', '106');
    final produto = produtoCarrinho();
    expect(
        await carrinho.inserir(produto, 'Comanda', '0', '4', '10', '',
            produto.id, produto.nome, 1, ''),
        isFalse);
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
  });

  test('troca rapida e inclusoes simultaneas nao misturam os carrinhos',
      () async {
    await abrir('4', '104');
    final adicoes = List.generate(20, (_) => adicionar());
    final troca = abrir('6', '106');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    await Future.wait([...adicoes, troca]);
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.quantidadeTotal, 20);
  });

  test('mesa, balcao e outra empresa nao recebem produtos da comanda',
      () async {
    await abrir('4', '104');
    await adicionar();
    await abrir('4', '204', tipo: 'mesa');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    await abrir('', '0', tipo: 'balcao');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    usuario.setUsuario(UsuarioModelo(empresa: '33'));
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    usuario.setUsuario(UsuarioModelo(empresa: '32'));
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
  });

  test('carrinho antigo sem identificacao nunca e atribuido a uma comanda',
      () async {
    final antigo = jsonEncode([produtoCarrinho().toMap()]);
    SharedPreferences.setMockInitialValues({'carrinho': antigo});
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(
        (await SharedPreferences.getInstance()).getString('carrinho'), antigo);
  });

  test('pizza salva e recorrente preservam sabores, adicionais e observacoes',
      () async {
    final pizza = produtoCarrinho()
      ..nome = 'Pizza'
      ..observacao = 'Sem cebola'
      ..opcoesPacotesListaFinal = [
        for (final (id, titulo, nomes) in [
          (9, 'Tamanho Pizza', ['G']),
          (10, 'Sabores Pizza', ['Mussarela', 'Calabresa']),
          (6, 'Bordas', ['Catupiry', 'Cheddar']),
          (7, 'Adicionais', ['Bacon']),
          (8, 'Retirar', ['Cebola']),
        ])
          ModeloOpcoesPacotes(
              id: id,
              titulo: titulo,
              obrigatorio: false,
              dados: [
                for (final nome in nomes)
                  ModeloDadosOpcoesPacotes(
                      id: nome, nome: nome, valor: '10', quantidade: 1)
              ])
      ];
    await abrir('4', '104');
    await adicionar(produto: pizza);
    await recorrentes.inserir('104', pizza);
    await abrir('6', '106');
    expect(recorrentes.itensCarrinho, isEmpty);
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.listaComandosPedidos.single.toMap(),
        pizza.toMap());
    expect(recorrentes.itensCarrinho.single.toMap(), pizza.toMap());
  });

  for (final status in ['Finalizada', 'Cancelada']) {
    test('$status limpa ambos os carrinhos sem afetar a comanda 6', () async {
      await abrir('6', '106');
      await adicionar();
      await abrir('4', '104');
      await adicionar();
      await recorrentes.inserir('104', produtoCarrinho());
      api.status = status;
      await ServicoCardapio(api, usuario)
          .listarPorId('104', TipoCardapio.comanda, 'Não');
      await carrinho.listarComandasPedidos();
      await recorrentes.listarComandasPedidos('104');
      expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
      expect(recorrentes.itensCarrinho, isEmpty);
      expect(await adicionar(), isFalse);
      expect(await recorrentes.inserir('104', produtoCarrinho()), isFalse);
      await abrir('6', '106');
      expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    });
  }

  test(
      'atualizacao com comanda livre ou reutilizada descarta o atendimento antigo',
      () async {
    for (final novoId in [null, '304']) {
      await abrir('4', '104');
      await armazenamento.atualizarStatus('32', '104', 'Andamento');
      await adicionar();
      await recorrentes.inserir('104', produtoCarrinho());
      api.resposta = [
        {
          'titulo': 'Comandas',
          'comandas': [
            {
              'id': '4',
              'codigo': '4',
              'nome': 'Comanda 4',
              'ativo': 'Sim',
              'comandaOcupada': novoId != null,
              'idComandaPedido': novoId
            }
          ]
        }
      ];
      await ServicoComandas(api, usuario).listar('4');
      await abrir('4', novoId ?? '304');
      expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
      expect(recorrentes.itensCarrinho, isEmpty);
      final antigo = ContextoCarrinho(
          empresa: '32', tipo: 'comanda', idAtendimento: '104');
      expect(await armazenamento.listar(antigo), isEmpty);
      expect(await armazenamento.listar(antigo, recorrentes: true), isEmpty);
    }
  });

  test(
      'pesquisa parcial e falha de rede nao apagam carrinhos fora do resultado',
      () async {
    await abrir('4', '104');
    await adicionar();
    api.resposta = <dynamic>[];
    final comandas = ServicoComandas(api, usuario);
    await comandas.listar('6');
    api.falhar = true;
    await expectLater(comandas.listar(''), throwsA(isA<DioException>()));
    await carrinho.listarComandasPedidos();
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
  });

  test(
      'fechamento para conferencia bloqueia adicoes e preserva o rascunho ate finalizar',
      () async {
    await abrir('4', '104');
    await adicionar();
    final cardapio = ServicoCardapio(api, usuario);
    api.resposta = {'sucesso': false, 'mensagem': 'Recusado'};
    expect((await cardapio.fecharAbrirComanda('104', 'Fechamento')).sucesso,
        isFalse);
    await carrinho.listarComandasPedidos();
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    api.resposta = {'sucesso': true, 'mensagem': 'Fechado'};
    expect((await cardapio.fecharAbrirComanda('104', 'Fechamento')).sucesso,
        isTrue);
    await carrinho.listarComandasPedidos();
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    expect(await adicionar(), isFalse);
    await cardapio.fecharAbrirComanda('104', 'Andamento');
    expect(await adicionar(), isTrue);
    expect(carrinho.itensCarrinho.quantidadeTotal, 2);
    api.status = 'Finalizada';
    await cardapio.listarPorId('104', TipoCardapio.comanda, 'Não');
    await carrinho.listarComandasPedidos();
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
  });

  test(
      'recorrentes antigos sao recuperados so para atendimento confirmado e uma unica vez',
      () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'itens_recorrentes',
        jsonEncode([
          jsonEncode({
            'idComandaPedido': '104',
            'produtos': [produtoCarrinho().toMap()]
          }),
          jsonEncode({
            'idComandaPedido': '106',
            'produtos': [produtoCarrinho().toMap()]
          }),
        ]));
    await abrir('4', '104');
    final leitura = ServicosItensRecorrentes(api, usuario);
    await leitura.listarPorId('104', TipoCardapio.comanda, 'Sim');
    await recorrentes.listarComandasPedidos('104');
    expect(recorrentes.itensCarrinho, hasLength(1));
    await recorrentes.removerComandasPedidos('104');
    await leitura.listarPorId('104', TipoCardapio.comanda, 'Sim');
    await recorrentes.listarComandasPedidos('104');
    expect(recorrentes.itensCarrinho, isEmpty);
    await abrir('6', '106');
    api.status = 'Finalizada';
    await leitura.listarPorId('106', TipoCardapio.comanda, 'Sim');
    api.status = 'Andamento';
    await leitura.listarPorId('106', TipoCardapio.comanda, 'Sim');
    await recorrentes.listarComandasPedidos('106');
    expect(recorrentes.itensCarrinho, isEmpty);
  });

  test(
      'pedido aberto envia os itens corretos e falha de rede preserva o rascunho',
      () async {
    await abrir('4', '104');
    await adicionar();
    final cardapio = ServicoCardapio(api, usuario);
    api.falhar = true;
    final falha = await cardapio.inserirProdutosComanda(
        carrinho.itensCarrinho.listaComandosPedidos, '0', '104', '4', '0');
    expect(falha.$1, isFalse);
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    api.falhar = false;
    api.resposta = {'sucesso': true, 'mensagem': 'OK'};
    expect(
        (await cardapio.inserirProdutosComanda(
                carrinho.itensCarrinho.listaComandosPedidos,
                '0',
                '104',
                '4',
                '0'))
            .$1,
        isTrue);
    final envio = jsonDecode(api.chamadas.last.data as String);
    expect(envio['id_comanda'], '4');
    expect(envio['id_comanda_pedido'], '104');
    expect(
        (envio['produtos'] as List)
            .map((item) => item is String ? jsonDecode(item) : item),
        [produtoCarrinho().toMap()]);
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
  });

  test('preflight impede lancamento e impressao de atendimento encerrado',
      () async {
    await abrir('4', '104');
    await adicionar();
    api.status = 'Finalizada';
    final finalizacao = FinalizacaoComPreparo();
    var imprimiu = false;
    final resultado = await finalizacao.executar(
      prepararImpressao: () => ['impressao'],
      registrarPedido: () async => (await ServicoCardapio(api, usuario)
              .inserirProdutosComanda(
                  [produtoCarrinho()], '0', '104', '4', '0'))
          .$1,
      enviarImpressao: (_) async => imprimiu = true,
      limparCarrinho: () async {},
    );
    expect(resultado, isFalse);
    expect(imprimiu, isFalse);
    expect(api.chamadas.where((chamada) => chamada.method == 'POST'), isEmpty);
  });

  test('conclusao limpa o carrinho de origem mesmo depois de trocar comanda',
      () async {
    await abrir('4', '104');
    await adicionar();
    final origem = carrinho.contexto!;
    final envio = Completer<void>();
    final finalizacao = FinalizacaoComPreparo();
    var registros = 0;
    final finalizar = finalizacao.executar(
      prepararImpressao: () => ['impressao da comanda 4'],
      registrarPedido: () async {
        registros++;
        return true;
      },
      enviarImpressao: (_) => envio.future,
      limparCarrinho: () async {
        await carrinho.removerComandasPedidos(contexto: origem);
      },
    );
    await abrir('6', '106');
    await adicionar();
    envio.complete();
    expect(await finalizar, isTrue);
    expect(registros, 1);
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
    await abrir('4', '104');
    expect(carrinho.itensCarrinho.listaComandosPedidos, isEmpty);
  });

  test('resposta antiga de consulta nao limpa atendimento aberto depois dela',
      () async {
    final recebida = Completer<(RequestOptions, RequestInterceptorHandler)>();
    api.cliente.interceptors.insert(0,
        InterceptorsWrapper(onRequest: (opcoes, handler) {
      if (opcoes.queryParameters['pesquisa'] == 'antiga') {
        recebida.complete((opcoes, handler));
      } else {
        handler.next(opcoes);
      }
    }));
    final comandas = ServicoComandas(api, usuario);
    final antiga = comandas.listar('antiga');
    final (opcoes, handler) = await recebida.future;
    api.resposta = [
      {
        'titulo': 'Ocupadas',
        'comandas': [
          {
            'id': '4',
            'codigo': '4',
            'nome': '4',
            'ativo': 'Sim',
            'comandaOcupada': true,
            'idComandaPedido': '304'
          }
        ]
      }
    ];
    await comandas.listar('nova');
    await abrir('4', '304');
    await adicionar();
    handler.resolve(Response(requestOptions: opcoes, statusCode: 200, data: [
      {
        'titulo': 'Livres',
        'comandas': [
          {
            'id': '4',
            'codigo': '4',
            'nome': '4',
            'ativo': 'Sim',
            'comandaOcupada': false,
            'idComandaPedido': null
          }
        ]
      }
    ]));
    await antiga;
    await carrinho.listarComandasPedidos();
    expect(carrinho.itensCarrinho.quantidadeTotal, 1);
  });

  testWidgets(
      'navegacao real entre cardapios mostra somente os produtos da comanda',
      (tester) async {
    final cardapio = ProvedorCardapio(CategoriasTeste(), usuario);
    final produtos = ProdutosTeste()..produtos.clear();
    produtos.produtos.add(produtoCarrinho());
    Modular.init(ModuloTeste(cardapio, usuario, produtos));
    final carrinhoDaTela = Modular.get<ProvedorCarrinho>();
    addTearDown(() {
      Modular.destroy();
      carrinhoDaTela.dispose();
      cardapio.dispose();
    });
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: Builder(
                builder: (context) => Column(
                      children: [
                        for (final numero in ['4', '6'])
                          TextButton(
                              onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                      builder: (_) => PaginaCardapio(
                                          tipo: TipoCardapio.comanda,
                                          id: '10$numero',
                                          idComanda: numero))),
                              child: Text('Comanda $numero'))
                      ],
                    )))));
    await tester.tap(find.text('Comanda 4'));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.byWidgetPredicate(
          (widget) => widget is CardProduto && widget.item.id == '1010'));
      await tester.pumpAndSettle();
    }
    expect(carrinhoDaTela.itensCarrinho.quantidadeTotal, 2);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comanda 6'));
    await tester.pumpAndSettle();
    expect(carrinhoDaTela.itensCarrinho.listaComandosPedidos, isEmpty);
    expect(
        find.byKey(const ValueKey('quantidade_carrinho_1010')), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Comanda 4'));
    await tester.pumpAndSettle();
    expect(carrinhoDaTela.itensCarrinho.quantidadeTotal, 2);
    expect(
        find.byKey(const ValueKey('quantidade_carrinho_1010')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
