import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:app/src/modulos/delivery/servicos/fila_delivery_offline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../essencial/utils/impressao_preparo_test.dart' show produto;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late Directory pasta;
  late BancoLocal banco;
  late FilaDeliveryOffline fila;
  const servidor = 'http://servidor/api1/';
  final escopo = BancoLocal.escopo(servidor, '32', '8');

  FilaDeliveryOffline criarFila([String? outroEscopo]) =>
      FilaDeliveryOffline(banco,
          escopo: outroEscopo ?? escopo,
          empresa: '32',
          usuario: '8',
          destino: 'servidor:9980');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pasta = await Directory.systemTemp.createTemp('delivery-offline-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    banco.servidor = servidor;
    BancoLocal.instancia = banco;
    fila = criarFila();
    await banco.gravar('estado:$escopo',
        jsonEncode({'offline_delivery': 1, 'caixa_id': '45'}));
  });

  tearDown(() async {
    BancoLocal.instancia = null;
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  Future<String> criar() => fila.criar(
          cliente: '9',
          endereco: '2',
          tipo: '1',
          observacao: 'Sem campainha',
          taxa: 4,
          exibicao: {
            'nomeCliente': 'Cliente de teste',
            'celularCliente': '(44) 99999-9999',
            'enderecoCliente': 'Rua A'
          });

  ContextoCarrinho contexto(String id) =>
      ContextoCarrinho(empresa: '32', tipo: 'delivery', idAtendimento: id);

  Future<void> adicionar(String id) async {
    final item = produto(nome: 'Almoço')..observacao = 'Pouco arroz';
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto(id), (itens) => itens.add(item));
    await fila.inserirProdutos(id, [item]);
  }

  Map<String, dynamic> pagamento(String chave, double valor,
          {double troco = 0, double desconto = 0}) =>
      {
        'chavePagamento': chave,
        'pagamentoSelecionado': 1,
        'valor_lancamento': valor.toStringAsFixed(2),
        'valortroco': troco.toStringAsFixed(2),
        'valordesconto': desconto.toStringAsFixed(2),
        'valoracrescimo': '0.00',
      };

  test(
      'rascunho, taxa e dados do cliente sobrevivem ao reinicio e isolam conta',
      () async {
    final id = await criar();
    await banco.db.close();
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    banco.servidor = servidor;
    BancoLocal.instancia = banco;
    fila = criarFila();
    final pedido = (await fila.listar()).single;
    expect(pedido.id, id);
    expect(pedido.nome, 'Cliente de teste');
    expect(pedido.possuiCelularCliente, isTrue);
    expect(pedido.endereco, 'Rua A');
    expect(pedido.observacao, 'Sem campainha');
    expect(pedido.taxaEntrega, 4);
    expect(await criarFila(BancoLocal.escopo(servidor, '32', '9')).listar(),
        isEmpty);
    await expectLater(
        criarFila(BancoLocal.escopo(servidor, '1', '8')).pedido(id),
        throwsStateError);
    expect(await banco.operacoes(escopo), isEmpty);
  });

  test('move carrinho e todos os detalhes ao rascunho em um commit', () async {
    final id = await criar();
    await adicionar(id);
    final pedido = await fila.pedido(id);
    expect(pedido.total, 54);
    expect(pedido.produtos.single.nome, 'Almoço');
    expect(pedido.produtos.single.observacao, 'Pouco arroz');
    expect(
        await ArmazenamentoCarrinhos.instancia.listar(contexto(id)), isEmpty);
    expect(await banco.operacoes(escopo), isEmpty);
    await expectLater(
        fila.inserirProdutos(id, [produto(nome: 'Almoço')]), throwsStateError);
    expect((await fila.pedido(id)).quantidade, 1);
  });

  test('troca modalidade e endereco recalculando a taxa do rascunho', () async {
    final id = await criar();
    await adicionar(id);
    expect((await fila.pedido(id)).total, 54);

    await fila.definirTaxa(id, '2', 0, endereco: '0');
    var pedido = await fila.pedido(id);
    expect(pedido.tipoEntrega, '2');
    expect(pedido.taxaEntrega, 0);
    expect(pedido.total, 50);

    await fila.definirTaxa(
      id,
      '1',
      7,
      endereco: '3',
      dadosEndereco: {
        'endereco': 'Rua Nova',
        'numero': '20',
        'bairro': 'Bairro 2',
        'cidade': 'Cidade',
      },
    );
    pedido = await fila.pedido(id);
    expect(pedido.tipoEntrega, '1');
    expect(pedido.texto('idendereco'), '3');
    expect(pedido.taxaEntrega, 7);
    expect(pedido.total, 57);
    expect(pedido.endereco, 'Rua Nova, 20, Bairro 2, Cidade');
  });

  test('excluir rascunho remove pedido e carrinho associado no mesmo commit',
      () async {
    final id = await criar();
    await ArmazenamentoCarrinhos.instancia.alterar(
        contexto(id), (itens) => itens.add(produto(nome: 'Em edição')));
    expect((await fila.listar()).single.quantidade, 1);

    await fila.excluirRascunho(id);

    expect(await fila.listar(), isEmpty);
    await expectLater(fila.pedido(id), throwsStateError);
    final carrinhos =
        jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}') as Map;
    expect(carrinhos.containsKey(contexto(id).chave), isFalse);
    expect(await banco.operacoes(escopo), isEmpty);
  });

  test('nao exclui pedido que ja entrou na fila de sincronizacao', () async {
    final id = await criar();
    await adicionar(id);
    await fila.confirmar(id);

    await expectLater(fila.excluirRascunho(id), throwsStateError);

    expect((await fila.listar()).single.id, id);
    expect(await banco.operacoes(escopo), hasLength(1));
  });

  test('peso arredonda por linha como a API, sem deixar centavo pendente',
      () async {
    final id = await criar();
    final itens = [
      produto()
        ..valorVenda = '45'
        ..quantidade = .201,
      produto()
        ..valorVenda = '45'
        ..quantidade = .201,
    ];
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto(id), (carrinho) => carrinho.addAll(itens));
    await fila.inserirProdutos(id, itens);
    expect((await fila.pedido(id)).total, 22.10);
    await fila.pagar(id, pagamento('peso', 22.10));
    await fila.concluir(id);
    await fila.confirmar(id);
    expect((await fila.pedido(id)).restante, 0);
  });

  test('Pagar depois preserva ajustes e nao depende de caixa aberto', () async {
    await banco.gravar(
        'estado:$escopo', jsonEncode({'offline_delivery': 1, 'caixa_id': '0'}));
    final id = await criar();
    await adicionar(id);
    await fila.definirAjustes(id, desconto: 5, acrescimo: 2);
    await fila.confirmar(id);
    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['valor_desconto'], '5.00');
    expect(dados['valor_acrescimo'], '2.00');
    expect(dados['pagamentos'], isEmpty);
    expect((await fila.pedido(id)).total, 51);
  });

  test('pagamento aceita estado confirmado sem caixa aberto', () async {
    await banco.gravar(
        'estado:$escopo', jsonEncode({'offline_delivery': 1, 'caixa_id': '0'}));
    final id = await criar();
    await adicionar(id);

    await fila.pagar(id, pagamento('sem-caixa', 20));
    await fila.confirmar(id);

    expect((await fila.pedido(id)).pago, 20);
    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['caixa_id'], '0');
    expect(dados['pagamentos'], hasLength(1));
  });

  test('primeiro pagamento usa caixa aberto depois de criar o Delivery',
      () async {
    await banco.gravar(
        'estado:$escopo', jsonEncode({'offline_delivery': 1, 'caixa_id': '0'}));
    final id = await criar();
    await adicionar(id);
    await banco.gravar('estado:$escopo',
        jsonEncode({'offline_delivery': 1, 'caixa_id': '71'}));

    await fila.pagar(id, pagamento('caixa-novo', 54));
    await fila.confirmar(id);

    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['caixa_id'], '71');
  });

  test('bloqueia somente quando servidor nunca informou o estado do caixa',
      () async {
    await banco.gravar('estado:$escopo', jsonEncode({'offline_delivery': 1}));
    final id = await criar();
    await adicionar(id);

    await expectLater(
      fila.pagar(id, pagamento('sem-estado', 20)),
      throwsA(isA<StateError>()
          .having((erro) => erro.message, 'mensagem', contains('Sincronize'))),
    );
    expect((await fila.pedido(id)).pago, 0);
  });

  test('lista mostra carrinho restaurado e bloqueia pagamento de resumo antigo',
      () async {
    final id = await criar();
    await adicionar(id);
    final item = produto(id: '101', nome: 'Bebida');
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto(id), (itens) => itens.add(item));
    final cartao = (await fila.listar()).single;
    expect(cartao.quantidade, 2);
    expect(cartao.total, 104);
    expect(cartao.possuiRascunhoLocal, isTrue);
    await expectLater(
        fila.pagar(id, pagamento('saldo-antigo', 54)), throwsStateError);
    await expectLater(fila.confirmar(id), throwsStateError);
    expect((await fila.pedido(id)).pago, 0);
    await fila.inserirProdutos(id, [item]);
    await fila.confirmar(id);
    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['produtos'], hasLength(2));
  });

  test('erro de disco mantem os produtos no carrinho sem duplicar o rascunho',
      () async {
    final id = await criar();
    final item = produto();
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto(id), (itens) => itens.add(item));
    await banco.db
        .execute("CREATE TRIGGER falha_delivery BEFORE INSERT ON documentos "
            "WHEN NEW.chave LIKE 'delivery_rascunhos_v1:%' "
            "BEGIN SELECT RAISE(ABORT, 'disco indisponivel'); END");
    await expectLater(
        fila.inserirProdutos(id, [item]), throwsA(isA<DatabaseException>()));
    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto(id)),
        hasLength(1));
    expect((await fila.pedido(id)).produtos, isEmpty);
  });

  test(
      'Pagar depois enfileira snapshot unico duravel e impede alteracao posterior',
      () async {
    final id = await criar();
    await adicionar(id);
    await fila.confirmar(id);
    await fila.confirmar(id);
    final operacao = (await banco.operacoes(escopo)).single;
    expect(operacao['acao'], 'delivery');
    expect(operacao['atendimento'], id);
    expect(operacao['estado'], 'pendente');
    final dados = jsonDecode(operacao['dados'] as String) as Map;
    expect(dados['produtos'], hasLength(1));
    expect(dados['pagamentos'], isEmpty);
    expect(dados['concluido'], isTrue);
    expect(dados['caixa_id'], '45');
    expect(dados['empresa'], '32');
    expect((await fila.pedido(id)).aguardandoSincronizacao, isTrue);
    await expectLater(fila.definirTaxa(id, '1', 7), throwsStateError);
    await expectLater(fila.pagar(id, pagamento('novo', 5)), throwsStateError);
  });

  test('pagamentos parciais preservam saldo, chave e troco sem duplicacao',
      () async {
    final id = await criar();
    await adicionar(id);
    await fila.pagar(id, pagamento('primeiro', 20));
    await fila.pagar(id, pagamento('primeiro', 20));
    expect((await fila.pedido(id)).restante, 34);
    await expectLater(
        fila.pagar(id, pagamento('primeiro', 21)), throwsStateError);
    await expectLater(fila.concluir(id), throwsStateError);
    await expectLater(
        fila.pagar(id, pagamento('excesso', 35)), throwsStateError);
    await fila.pagar(id, pagamento('segundo', 40, troco: 6));
    expect((await fila.pedido(id)).restante, 0);
    await fila.concluir(id);
    await fila.confirmar(id);
    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['pagamentos'], hasLength(2));
    expect(dados['produtos'], hasLength(1));
  });

  test('retoma parcial apos reinicio e Pagar depois conserva o snapshot',
      () async {
    final id = await criar();
    await adicionar(id);
    final parcial = pagamento('primeiro', 20, desconto: 6)
      ..['valoracrescimo'] = '2.00';
    await fila.pagar(id, parcial);
    await banco.db.close();
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    banco.servidor = servidor;
    BancoLocal.instancia = banco;
    fila = criarFila();
    final retomado = (await fila.listar()).single;
    expect(retomado.total, 50);
    expect(retomado.pago, 20);
    expect(retomado.restante, 30);
    expect(retomado.produtosConfirmadosLocal, isTrue);
    expect(retomado.texto('valorDesconto'), '6.00');
    expect(retomado.texto('valorAcrescimo'), '2.00');
    await fila.definirAjustes(id, desconto: 6, acrescimo: 2);
    await fila.confirmar(id);
    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['valor_desconto'], '6.00');
    expect(dados['valor_acrescimo'], '2.00');
    expect(dados['pagamentos'], [parcial]);
    expect(dados['concluido'], isTrue);
    expect((await fila.pedido(id)).restante, 30);
  });

  test(
      'desconto fica preservado e nao pode ser alterado apos pagamento parcial',
      () async {
    final id = await criar();
    await adicionar(id);
    await fila.pagar(id, pagamento('primeiro', 20, desconto: 4));
    expect((await fila.pedido(id)).total, 50);
    expect((await fila.pedido(id)).restante, 30);
    await expectLater(
        fila.pagar(id, pagamento('segundo', 30)), throwsStateError);
    expect((await fila.pedido(id)).total, 50);
    await fila.pagar(id, pagamento('segundo', 30, desconto: 4));
    await fila.confirmar(id);
    final dados =
        jsonDecode((await banco.operacoes(escopo)).single['dados'] as String)
            as Map;
    expect(dados['valor_desconto'], '4.00');
    expect(dados['pagamentos'], hasLength(2));
  });

  test(
      'falha ao gravar operacao preserva rascunho e pagamentos para tentar novamente',
      () async {
    final id = await criar();
    await adicionar(id);
    await fila.pagar(id, pagamento('primeiro', 54));
    await banco.db
        .execute("CREATE TRIGGER falha_fila BEFORE INSERT ON operacoes "
            "BEGIN SELECT RAISE(ABORT, 'disco indisponivel'); END");
    await expectLater(fila.confirmar(id), throwsA(isA<DatabaseException>()));
    expect((await fila.pedido(id)).aguardandoSincronizacao, isFalse);
    expect((await fila.pedido(id)).pago, 54);
    expect((await fila.pedido(id)).produtos, hasLength(1));
    expect(await banco.operacoes(escopo), isEmpty);
  });

  test(
      'pendencia fica visivel e sai da lista local somente depois de confirmada',
      () async {
    final id = await criar();
    await adicionar(id);
    await fila.confirmar(id);
    final op = (await banco.operacoes(escopo)).single;
    await banco.atualizarOperacao(
        op['id'] as String, {'estado': 'conflito', 'erro': 'Caixa encerrado'});
    expect((await fila.listar()).single.texto('erroSincronizacao'),
        'Caixa encerrado');
    await banco.atualizarOperacao(op['id'] as String, {
      'estado': 'registrado',
      'resposta': jsonEncode({'idDelivery': '501', 'numeroPedido': '20'})
    });
    expect((await fila.pedido(id)).numeroOperacional, '20');
    await banco.atualizarOperacao(op['id'] as String, {
      'estado': 'concluido',
      'resposta': jsonEncode({'idDelivery': '501', 'numeroPedido': '20'})
    });
    expect(await fila.listar(), isEmpty);
    expect((await fila.pedido(id)).produtos, hasLength(1));
  });
}
