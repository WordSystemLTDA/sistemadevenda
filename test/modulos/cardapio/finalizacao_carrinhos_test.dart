import 'dart:async';
import 'dart:convert';

import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_editar_observacao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servicos_itens_comanda.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/pagina_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../essencial/utils/envio_impressao_test.dart'
    show CanalTeste, SaidaTeste;
import '../../essencial/utils/impressao_preparo_test.dart'
    show produto, saboresPizza;
import 'montagem_pizza_test.dart' show CategoriasTeste;

class ApiFinalizacaoTeste extends Fake implements DioCliente {
  @override
  final cliente = Dio();
  final pedidos = <Map<String, dynamic>>[];
  String? idResposta;

  ApiFinalizacaoTeste() {
    cliente.interceptors.add(InterceptorsWrapper(onRequest: (opcoes, handler) {
      Object dados = [];
      if (opcoes.path.startsWith('cardapio/listar_por_id.php')) {
        final id = idResposta ?? opcoes.uri.queryParameters['id']!;
        final tipoParametro = opcoes.uri.queryParameters['tipo']?.toLowerCase();
        final tipo =
            tipoParametro == 'mesa' ? TipoCardapio.mesa : TipoCardapio.comanda;
        final numero = id.startsWith('10') ? id.substring(2) : id;
        final mesa = tipo == TipoCardapio.mesa;
        dados = {
          'id': id,
          'status': 'Andamento',
          'nome': mesa ? 'Mesa: $numero' : 'Comanda: $numero',
          'numeroPedido': id,
          'idComanda': mesa ? '0' : numero,
          'idMesa': mesa ? numero : '0',
          'idCliente': '0',
          'nomeCliente': '',
          'observacaoDoPedido': 'Cliente $numero',
          'nomeEmpresa': 'Pizzaria',
        };
      } else if (opcoes.method == 'POST') {
        pedidos.add(jsonDecode(opcoes.data as String) as Map<String, dynamic>);
        dados = {'sucesso': true, 'mensagem': 'Ok'};
      }
      handler.resolve(
          Response(requestOptions: opcoes, statusCode: 200, data: dados));
    }));
  }
}

class ServidorFinalizacaoTeste extends Server {
  final mensagens = <Map<String, dynamic>>[];

  ServidorFinalizacaoTeste() {
    connected = true;
    hostname = 'Cozinha';
    channel = CanalTeste(SaidaTeste((data) {
      final mensagem = Map<String, dynamic>.from(
          jsonDecode(data as String)['data']['customData']);
      mensagens.add(mensagem);
      if (mensagem['tipoImpressao'] == '1') {
        onData({
          'tipo': 'RespostaImpressao',
          'tipoResposta': 'impressao',
          'statusResposta': 'sucesso',
          'protocoloImpressao': 2,
          'idRequisicao': mensagem['idRequisicao'],
        });
      }
    }));
  }

  List<Map<String, dynamic>> get impressos =>
      mensagens.where((e) => e['tipoImpressao'] == '1').toList();
}

class CarrinhoFinalizacaoTeste extends ProvedorCarrinho {
  CarrinhoFinalizacaoTeste(super.servico);
  Completer<void>? esperaEdicao;

  @override
  Future<bool> editar(Modelowordprodutos produto, int index,
      {ContextoCarrinho? contexto, Modelowordprodutos? original}) async {
    await esperaEdicao?.future;
    return super.editar(produto, index, contexto: contexto, original: original);
  }
}

class ModuloFinalizacaoTeste extends Module {
  final usuario = UsuarioProvedor()
    ..setUsuario(UsuarioModelo(empresa: '32', id: '1', nome: 'Garcom'));
  final api = ApiFinalizacaoTeste();
  final servidor = ServidorFinalizacaoTeste();
  late final cardapio = ProvedorCardapio(CategoriasTeste(), usuario);
  late final servico = ServicosItensComanda(api, usuario);
  late final carrinho = CarrinhoFinalizacaoTeste(servico);
  late final recorrentes = ProvedorItensRecorrentes(servico);

  @override
  void binds(Injector i) {
    i.addInstance<UsuarioProvedor>(usuario);
    i.addInstance<ProvedorCardapio>(cardapio);
    i.addInstance<ProvedorCarrinho>(carrinho);
    i.addInstance<ProvedorItensRecorrentes>(recorrentes);
    i.addInstance<ServicoCardapio>(ServicoCardapio(api, usuario));
    i.addInstance<ServicoConfigBigchef>(ServicoConfigBigchef(api, usuario));
    i.addInstance<ProvedorComanda>(
        ProvedorComanda(ServicoComandas(api, usuario)));
    i.addInstance<ProvedorMesas>(ProvedorMesas(ServicoMesas(api, usuario)));
    i.addInstance<ProvedorFinalizarPagamento>(ProvedorFinalizarPagamento());
    i.addInstance<Server>(servidor);
  }

  Future<void> selecionar(String numero,
      {TipoCardapio tipo = TipoCardapio.comanda}) async {
    final mesa = tipo == TipoCardapio.mesa;
    cardapio.id = '10$numero';
    cardapio.idComanda = mesa ? '0' : numero;
    cardapio.idMesa = mesa ? numero : '0';
    cardapio.idCliente = '0';
    await carrinho.selecionarAtendimento(
        tipo: tipo.name, idAtendimento: '10$numero', idRecurso: numero);
    recorrentes.selecionarAtendimento(
        tipo: tipo.name, idAtendimento: '10$numero', idRecurso: numero);
    await recorrentes.listarComandasPedidos('10$numero');
  }

  Future<void> adicionar(String nome, String codigo,
      {bool recorrente = false, bool pizza = false}) async {
    final item =
        produto(id: codigo, nome: nome, codigo: codigo, computador: 'Bar')
          ..valorVenda = codigo == '1010' ? '10' : '6'
          ..opcoesPacotesListaFinal = pizza ? [saboresPizza()] : [];
    expect(
        recorrente
            ? await recorrentes.inserir(carrinho.contexto!.idAtendimento, item)
            : await carrinho.inserir(
                item,
                TipoCardapio.values.byName(carrinho.contexto!.tipo).nome,
                carrinho.contexto!.tipo == 'mesa'
                    ? carrinho.contexto!.idRecurso
                    : '0',
                carrinho.contexto!.idRecurso,
                item.valorVenda,
                '',
                item.id,
                item.nome,
                1,
                ''),
        isTrue);
  }

  Widget pagina(bool recorrente, {bool deliveryDireto = false}) {
    final contexto = carrinho.contexto!;
    final tipo = TipoCardapio.values.byName(contexto.tipo);
    return recorrente
        ? PaginaCarrinhoItensRecorrentes(
            idComanda: tipo == TipoCardapio.comanda ? contexto.idRecurso : '0',
            idComandaPedido: contexto.idAtendimento,
            idMesa: tipo == TipoCardapio.mesa ? contexto.idRecurso : '0',
            idCliente: '0',
            tipo: tipo)
        : PaginaCarrinho(deliveryDireto: deliveryDireto);
  }

  Future<void> montar(WidgetTester tester,
      {bool recorrente = false,
      TipoCardapio tipo = TipoCardapio.comanda,
      bool deliveryDireto = false}) async {
    final rotaDestino =
        tipo == TipoCardapio.mesa ? 'PaginaMesas' : 'PaginaComandas';
    await tester.pumpWidget(MaterialApp(
      initialRoute: rotaDestino,
      routes: {
        '/': (_) => const SizedBox.shrink(),
        rotaDestino: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                          builder: (context) => recorrente
                              ? Scaffold(
                                  body: TextButton(
                                      onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute<void>(
                                              builder: (_) => pagina(true))),
                                      child: const Text('Ver carrinho')),
                                )
                              : pagina(false, deliveryDireto: deliveryDireto))),
                  child: const Text('Abrir carrinho')),
            ),
      },
    ));
  }

  Future<void> abrir(WidgetTester tester, {bool recorrente = false}) async {
    await tester.tap(find.text('Abrir carrinho'));
    await tester.pumpAndSettle();
    if (recorrente) {
      await tester.tap(find.text('Ver carrinho'));
      await tester.pumpAndSettle();
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ModuloFinalizacaoTeste iniciar() {
    SharedPreferences.setMockInitialValues({});
    final modulo = ModuloFinalizacaoTeste();
    app.usuarioProvedor = modulo.usuario;
    Modular.init(modulo);
    addTearDown(() {
      modulo.servidor.dispose();
      modulo.carrinho.dispose();
      modulo.recorrentes.dispose();
      modulo.cardapio.dispose();
      modulo.usuario.dispose();
      modulo.api.cliente.close();
      Modular.destroy();
    });
    return modulo;
  }

  for (final recorrente in [false, true]) {
    for (final globaisAntigos in [false, true]) {
      testWidgets(
          'retoma 4 apos finalizar 6; recorrente=$recorrente, globais antigos=$globaisAntigos',
          (tester) async {
        final m = iniciar();
        await m.selecionar('4');
        await m.adicionar('Coca Cola 2L', '1010', recorrente: recorrente);
        await m.adicionar('Coca Cola 350ml', '1012', recorrente: recorrente);
        await m.selecionar('6');
        await m.adicionar('Coca Cola 2L', '1010', recorrente: recorrente);
        await m.montar(tester, recorrente: recorrente);
        await m.abrir(tester, recorrente: recorrente);
        await tester.tap(find.text('Finalizar'));
        await tester.pumpAndSettle();
        expect(m.api.pedidos.single['id_comanda_pedido'], '106');
        expect(m.servidor.impressos.single['comanda'], 'Comanda: 6');
        expect(m.servidor.impressos.single['produtos'].single['id'], '1010');

        await m.selecionar('4');
        if (globaisAntigos) {
          m.cardapio.id = '106';
          m.cardapio.idComanda = '6';
        }
        await m.abrir(tester, recorrente: recorrente);
        if (!recorrente) expect(find.byType(CardCarrinho), findsNWidgets(2));
        await tester.tap(find.text('Finalizar'));
        await tester.pumpAndSettle();
        expect(m.api.pedidos.last['id_comanda_pedido'], '104');
        final impresso = m.servidor.impressos.last;
        expect(impresso['comanda'], 'Comanda: 4');
        expect(impresso['nomeCliente'], 'Cliente 4');
        expect(impresso['numeroPedido'], '104');
        final enviados = impresso['produtos'] as List;
        expect(enviados.map((e) => e['id']), unorderedEquals(['1012', '1010']));
        expect(enviados.map((e) => e['quantidade']), [1, 1]);
        expect(
            enviados.fold<double>(
                0, (valor, e) => valor + double.parse(e['valorVenda'])),
            16);
        final lancados = (m.api.pedidos.last['produtos'] as List)
            .map((e) => jsonDecode(e as String));
        expect(lancados.map((e) => e['id']), enviados.map((e) => e['id']));
        expect(m.servidor.impressos.map((e) => e['idRequisicao']).toSet(),
            hasLength(2));
        expect(m.servidor.filaImpressao.itens, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }

    testWidgets(
        'observacao da pizza sobrevive a troca e chega na impressao; recorrente=$recorrente',
        (tester) async {
      final m = iniciar();
      await m.selecionar('4');
      await m.adicionar('Pizza', 'pizza', recorrente: recorrente, pizza: true);
      if (recorrente) await m.recorrentes.listarComandasPedidos('104');
      await tester.pumpWidget(MaterialApp(
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          builder: (_) => ModalEditarObservacao(
                              idProduto: 'pizza',
                              observacao: '',
                              index: 0,
                              itensRecorrentes: recorrente)),
                      child: const Text('Observacao'))))));
      await tester.tap(find.text('Observacao'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Sem cebola');
      await tester.tap(find.text('Salvar observação'));
      await tester.pumpAndSettle();
      expect(find.byType(ModalEditarObservacao), findsNothing);
      await m.selecionar('6');
      await m.selecionar('4');
      await tester.pumpWidget(const SizedBox.shrink());
      await m.montar(tester, recorrente: recorrente);
      await m.abrir(tester, recorrente: recorrente);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      final impresso = m.servidor.impressos.single['produtos'].single;
      expect(impresso['observacao'], 'Sem cebola');
      final opcoes = impresso['opcoesPacotesListaFinal'] as List;
      expect(opcoes.first['dados'], hasLength(2));
      // Observacao livre segue no campo proprio, nao como opcao comercial.
      expect(opcoes, hasLength(1));
      expect(opcoes.single['id'], 10);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets(
        'bloqueia resposta de outro atendimento; recorrente=$recorrente',
        (tester) async {
      final m = iniciar();
      await m.selecionar('4');
      await m.adicionar('Coca Cola 2L', '1010', recorrente: recorrente);
      m.api.idResposta = '106';
      await m.montar(tester, recorrente: recorrente);
      await m.abrir(tester, recorrente: recorrente);
      await tester.tap(find.text('Finalizar'));
      await tester.pumpAndSettle();
      expect(m.api.pedidos, isEmpty);
      expect(m.servidor.impressos, isEmpty);
      await m.selecionar('4');
      expect(
          recorrente
              ? m.recorrentes.itensCarrinho
              : m.carrinho.itensCarrinho.listaComandosPedidos,
          hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('carrinho recorrente de mesa volta para lista de mesas',
      (tester) async {
    final m = iniciar();
    await m.selecionar('8', tipo: TipoCardapio.mesa);
    await m.adicionar('Coca Cola 2L', '1010', recorrente: true);
    await m.montar(tester, recorrente: true, tipo: TipoCardapio.mesa);
    await m.abrir(tester, recorrente: true);
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();

    expect(m.api.pedidos.single['id_comanda_pedido'], '108');
    expect(m.api.pedidos.single['id_mesa'], '8');
    expect(m.api.pedidos.single.containsKey('id_comanda'), isFalse);
    expect(m.servidor.impressos.single['comanda'], 'Mesa: 8');
    expect(find.text('Abrir carrinho'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'atualizacao do carrinho mostra os mesmos produtos que serao enviados',
      (tester) async {
    final m = iniciar();
    await m.selecionar('4');
    await m.adicionar('Coca Cola 2L', '1010');
    await m.montar(tester);
    await m.abrir(tester);
    await m.adicionar('Coca Cola 350ml', '1012');
    await tester.pumpAndSettle();
    expect(find.byType(CardCarrinho), findsNWidgets(2));
    await tester.tap(find.text('Finalizar'));
    await tester.pumpAndSettle();
    expect(m.servidor.impressos.single['produtos'], hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('fechar observacao durante gravacao nao fecha o carrinho',
      (tester) async {
    final m = iniciar();
    await m.selecionar('4');
    await m.adicionar('Coca Cola 2L', '1010');
    await m.montar(tester);
    await m.abrir(tester);
    await tester.tap(find.text('Observação'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sem gelo');
    m.carrinho.esperaEdicao = Completer<void>();
    await tester.tap(find.text('Salvar observação'));
    await tester.pump();
    await tester.tap(find.byTooltip('Fechar'));
    await tester.pump(const Duration(milliseconds: 30));
    m.carrinho.esperaEdicao!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(ModalEditarObservacao), findsNothing);
    expect(find.byType(PaginaCarrinho), findsOneWidget);
    expect(m.carrinho.itensCarrinho.listaComandosPedidos.single.observacao,
        'Sem gelo');
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
