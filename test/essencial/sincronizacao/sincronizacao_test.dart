import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/atendimentos_locais.dart';
import 'package:app/src/modulos/comandas/servicos/servico_comandas.dart';
import 'package:app/src/modulos/mesas/servicos/servico_mesas.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/essencial/sincronizacao/pendencias_sincronizacao.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/impressao_preparo_test.dart' show produto;

class SocketOfflineTeste extends Server {
  @override
  Future<void> processarImpressoesPendentes() async {}
  @override
  bool write(String message) => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late SocketOfflineTeste socket;
  late Sincronizador sync;
  late Directory pasta;
  var conectado = false;
  var perderResposta = false;
  var conflito = false;
  var conflitoAbertura = false;
  final aplicados = <String>{};
  final tentativas = <Map<String, dynamic>>[];
  const contexto = ContextoCarrinho(
      empresa: '32', tipo: 'comanda', idAtendimento: '104', idRecurso: '4');

  setUp(() async {
    conectado = false;
    perderResposta = false;
    conflito = false;
    conflitoAbertura = false;
    aplicados.clear();
    tentativas.clear();
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})
    });
    pasta = await Directory.systemTemp.createTemp('garcom-teste-');
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    api = DioCliente();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32', nome: 'Garcom'));
    socket = SocketOfflineTeste();
    sync = Sincronizador(api, usuario, socket, banco: banco);
    api.cliente.interceptors
        .add(InterceptorsWrapper(onRequest: (options, handler) {
      final rota = CacheConsultas.caminho(options);
      Map<String, dynamic>? pedido;
      if (options.method == 'POST') {
        pedido = jsonDecode(options.data as String) as Map<String, dynamic>;
        tentativas.add(pedido);
      }
      if (!conectado) {
        handler.reject(DioException(
            requestOptions: options, type: DioExceptionType.connectionError));
        return;
      }
      if (pedido != null) {
        if ((conflito && pedido['dados']['id_comanda_pedido'] == '104') ||
            (conflitoAbertura && pedido['acao'] == 'abertura')) {
          handler.reject(DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(
                  requestOptions: options,
                  statusCode: 409,
                  data: {'mensagem': 'Atendimento encerrado'})));
          return;
        }
        aplicados.add(pedido['id_operacao'] as String);
        if (perderResposta) {
          perderResposta = false;
          handler.reject(DioException(
              requestOptions: options, type: DioExceptionType.receiveTimeout));
          return;
        }
        handler.resolve(Response(
            requestOptions: options,
            statusCode: 200,
            data: {
              'protocolo': 1,
              'sucesso': true,
              'id_operacao': pedido['id_operacao']
              ,if (pedido['acao'] == 'abertura') ...{
                'id_comanda_pedido': '201', 'versao_atendimento': 'nova-versao', 'numeroPedido': '31',
              },
              if (pedido['dados']['id_abertura'] != null) 'numeroPedido': '31',
              if (pedido['acao'] == 'venda') ...{'idVenda': '301', 'numeroPedido': '32'},
            }));
        return;
      }
      final Object dados = rota == 'sincronizacao/estado.php'
          ? {
              'protocolo': 1,
              'atendimentos': {
                '104': {'id': '104', 'versao': 'versao-original'},
                '106': {'id': '106', 'versao': 'versao-outra'},
              }
            }
          : rota == 'config_bigchef/listar.php'
              ? <String, dynamic>{}
              : [];
      handler.resolve(
          Response(requestOptions: options, data: dados, statusCode: 200));
    }));
    await sync.configurar();
    await banco.gravar(
        'estado:${sync.escopo}',
        jsonEncode({
          'abertura_offline': 1, 'caixa_id': '0',
          'recursos': {
            for (final tipo in ['mesa', 'comanda']) '$tipo:5': {
              'id': '5', 'nome': '5', 'codigo': '5', 'ativo': 'Sim', 'livre': true,
              'versao': 'livre-original-$tipo',
            },
          },
          'atendimentos': {
            '104': {'versao': 'versao-original'},
            '106': {'versao': 'versao-outra'},
          }
        }));
  });

  tearDown(() async {
    await sync.enviarPendentes();
    sync.dispose();
    socket.dispose();
    usuario.dispose();
    api.cliente.close(force: true);
    BancoLocal.instancia = null;
    await banco.db.close();
    await pasta.delete(recursive: true);
  });

  Future<void> guardar(
      {ContextoCarrinho alvo = contexto, bool recorrentes = false}) async {
    final item =
        produto(id: '5', nome: 'Pizza', codigo: '5', computador: 'Cozinha')
          ..quantidade = 2
          ..observacao = 'Sem cebola';
    await ArmazenamentoCarrinhos.instancia
        .alterar(alvo, (itens) => itens.add(item), recorrentes: recorrentes);
    await sync.guardarPedido(
        contexto: alvo,
        itens: [item],
        idMesa: '0',
        idComanda: alvo.idRecurso,
        idCliente: '0',
        recorrentes: recorrentes,
        impressoes: [
          jsonEncode({
            'idRequisicao': 'impressao-${alvo.idAtendimento}',
            'tipoImpressao': '1',
            'idEmpresa': '32',
            'produtos': [item.toMap()]
          })
        ]);
    await sync.enviarPendentes();
  }

  for (final recorrentes in [false, true]) {
    test(
        'salva pedido e limpa somente o carrinho correspondente; recorrentes=$recorrentes',
        () async {
      await guardar(recorrentes: recorrentes);
      final fila = await banco.operacoes(sync.escopo);
      expect(fila, hasLength(1));
      expect(fila.single['estado'], 'pendente');
      expect(socket.filaImpressao.itens, isEmpty);
      expect(
          await ArmazenamentoCarrinhos.instancia
              .listar(contexto, recorrentes: recorrentes),
          isEmpty);
      final salvo = jsonDecode(fila.single['dados'] as String);
      expect(salvo['produtos'].single['quantidade'], 2);
      expect(salvo['produtos'].single['observacao'], 'Sem cebola');
      expect(salvo['versao_atendimento'], 'versao-original');
      conectado = true;
      await sync.tentarNovamente();
      expect(await banco.operacoes(sync.escopo), isEmpty);
      expect(aplicados, hasLength(1));
      expect(socket.filaImpressao.itens, hasLength(1));
    });
  }

  test('resposta perdida repete o mesmo ID, sem registrar produtos duas vezes',
      () async {
    conectado = true;
    perderResposta = true;
    await guardar();
    expect(aplicados, hasLength(1));
    expect(socket.filaImpressao.itens, isEmpty);
    await sync.tentarNovamente();
    expect(aplicados, hasLength(1));
    expect(tentativas.map((p) => p['id_operacao']).toSet(), hasLength(1));
    expect(socket.filaImpressao.itens, hasLength(1));
  });

  for (final tipo in ['mesa', 'comanda']) {
    test('abre $tipo offline, permite produtos e imprime apos confirmar abertura', () async {
      Sincronizador.instancia = sync;
      final id = tipo == 'mesa'
          ? (await ServicoMesas(api, usuario).inserirMesaOcupada('5', '0', 'Bruno')).idcomandapedido
          : (await ServicoComandas(api, usuario).inserirComandaOcupada('5', '0', '0', 'Bruno')).idcomandapedido!;
      final tela = await ServicoCardapio(api, usuario).listarPorId(id, TipoCardapio.values.byName(tipo), 'Não');
      expect(tela.id, id);
      expect(tela.observacaoDoPedido, 'Bruno');
      final alvo = ContextoCarrinho(empresa: '32', tipo: tipo, idAtendimento: id, idRecurso: '5');
      final item = produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
      await ArmazenamentoCarrinhos.instancia.alterar(alvo, (itens) => itens.add(item));
      await sync.guardarPedido(contexto: alvo, itens: [item], idMesa: tipo == 'mesa' ? '5' : '0',
          idComanda: tipo == 'comanda' ? '5' : '0', idCliente: '0',
          impressoes: [jsonEncode({'idRequisicao': 'nova-$tipo', 'tipoImpressao': '1', 'numeroPedido': ''})]);
      await sync.enviarPendentes();
      expect(await banco.operacoes(sync.escopo), hasLength(2));
      expect(socket.filaImpressao.itens, isEmpty);
      final lista = await AtendimentosLocais(banco, sync.escopo).projetarLista([
        {'titulo': 'Livres', tipo == 'mesa' ? 'mesas' : 'comandas': [
          {'id': '5', 'nome': '5', 'codigo': '5', 'ativo': 'Sim',
            tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada': false}
        ]}
      ], tipo, '');
      expect(lista.first['titulo'], 'Ocupadas');
      expect(lista.first[tipo == 'mesa' ? 'mesas' : 'comandas'].single['idComandaPedido'], id);
      conectado = true;
      await sync.tentarNovamente();
      expect(await banco.operacoes(sync.escopo), isEmpty);
      expect(aplicados, hasLength(2));
      expect(socket.filaImpressao.itens.single.dados['numeroPedido'], '31');
      final enviados = tentativas.where((p) => p['acao'] == 'produtos');
      expect(enviados.single['dados']['id_abertura'], id.substring(6));
    });
  }

  test('abertura conflitante preserva itens, nao imprime e arquivar nao libera dependentes', () async {
    final id = await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5');
    await guardar(alvo: ContextoCarrinho(empresa: '32', tipo: 'comanda', idAtendimento: id, idRecurso: '5'));
    conectado = true;
    conflitoAbertura = true;
    await sync.tentarNovamente();
    expect(aplicados, isEmpty);
    expect(socket.filaImpressao.itens, isEmpty);
    final fila = await banco.operacoes(sync.escopo);
    expect(fila, hasLength(2));
    expect(fila.map((e) => e['estado']), everyElement('conflito'));
    await sync.arquivarConflito(id.substring(6));
    conflitoAbertura = false;
    await sync.tentarNovamente();
    expect(aplicados, isEmpty);
    expect(socket.filaImpressao.itens, isEmpty);
    expect(AtendimentosLocais.dados((await banco.operacoes(sync.escopo)).single)['produtos'], hasLength(1));
  });

  test('duplo toque nao abre duas comandas locais no mesmo recurso', () async {
    final resultados = await Future.wait([0, 1].map((_) async {
      try { return await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5'); }
      on StateError { return null; }
    }));
    expect(resultados.whereType<String>(), hasLength(1));
    await sync.enviarPendentes();
    expect(await banco.operacoes(sync.escopo), hasLength(1));
  });

  test('reinicio e resposta perdida da abertura preservam dependencia e identidade', () async {
    final id = await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5');
    await guardar(alvo: ContextoCarrinho(empresa: '32', tipo: 'comanda', idAtendimento: id, idRecurso: '5'));
    conectado = true;
    perderResposta = true;
    await sync.tentarNovamente();
    expect(socket.filaImpressao.itens, isEmpty);
    sync.dispose();
    await banco.db.close();
    banco = await BancoLocal.abrir(factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    sync = Sincronizador(api, usuario, socket, banco: banco);
    await sync.configurar();
    await sync.tentarNovamente();
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(aplicados, hasLength(2));
    expect(socket.filaImpressao.itens, hasLength(1));
  });

  test('venda offline e pagamento seguinte sobrevivem sem duplicar impressao', () async {
    const alvo = ContextoCarrinho(empresa: '32', tipo: 'balcao', idAtendimento: '0');
    final item = produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia.alterar(alvo, (itens) => itens.add(item));
    final id = await sync.guardarVenda(contexto: alvo, itens: [item],
        dados: {'produtos': [item.toMap()], 'empresa': '32', 'id_usuario': '1', 'valor_lancamento': '10'},
        impressoes: [jsonEncode({'idRequisicao': 'venda-1', 'tipoImpressao': '1'})]);
    await sync.guardarPagamentoVenda(id, {'empresa': '32', 'id_usuario': '1', 'valor_lancamento': '20'});
    await sync.enviarPendentes();
    expect(await ArmazenamentoCarrinhos.instancia.listar(alvo), isEmpty);
    expect(await banco.operacoes(sync.escopo), hasLength(2));
    conectado = true;
    await sync.tentarNovamente();
    expect(aplicados, hasLength(2));
    expect(socket.filaImpressao.itens.single.dados['numeroPedido'], '32');
    expect(socket.filaImpressao.itens.single.dados['comanda'], 'Balcão 301');
  });

  test(
      'conflito preserva os dados e nao impede outro atendimento de sincronizar',
      () async {
    await guardar();
    await guardar(
        alvo: const ContextoCarrinho(
            empresa: '32',
            tipo: 'comanda',
            idAtendimento: '106',
            idRecurso: '6'));
    conectado = true;
    conflito = true;
    await sync.tentarNovamente();
    final pendentes = await banco.operacoes(sync.escopo);
    expect(pendentes.single['estado'], 'conflito');
    expect(pendentes.single['atendimento'], '104');
    expect(jsonDecode(pendentes.single['dados'] as String)['produtos'],
        hasLength(1));
    expect(socket.filaImpressao.itens.single.id, 'impressao-106');
    final envios = tentativas.length;
    await sync.tentarNovamente();
    expect(tentativas.length, envios);
  });

  test('reabrir o banco recupera os pedidos ainda nao enviados', () async {
    await guardar();
    final fila = await banco.operacoes(sync.escopo);
    sync.dispose();
    await banco.db.close();
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    sync = Sincronizador(api, usuario, socket, banco: banco);
    await sync.configurar();
    expect(
        (await banco.operacoes(sync.escopo)).single['id'], fila.single['id']);
    conectado = true;
    await sync.tentarNovamente();
    expect(aplicados, hasLength(1));
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test('erro ao gravar o carrinho reverte a inclusao na fila', () async {
    final item =
        produto(id: '5', nome: 'Pizza', codigo: '5', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto, (itens) => itens.add(item));
    await banco.db.execute(
        "CREATE TEMP TRIGGER simular_disco_cheio BEFORE INSERT ON documentos "
        "WHEN NEW.chave LIKE 'carrinhos:%' BEGIN SELECT RAISE(ABORT, 'disco cheio'); END");
    await expectLater(
        sync.guardarPedido(
            contexto: contexto,
            itens: [item],
            idMesa: '0',
            idComanda: '4',
            idCliente: '0',
            impressoes: []),
        throwsA(isA<DatabaseException>()));
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(
        await ArmazenamentoCarrinhos.instancia.listar(contexto), hasLength(1));
  });

  test('arquivar conflito nao envia ou apaga o pedido', () async {
    await guardar();
    conectado = true;
    conflito = true;
    await sync.tentarNovamente();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    await sync.arquivarConflito(pendente['id'] as String);
    expect(await banco.operacoes(sync.escopo), isEmpty);
    final historico = await banco.db.query('operacoes');
    expect(historico.single['estado'], 'arquivado');
    expect(historico.single['dados'], pendente['dados']);
    expect(aplicados, isEmpty);
    expect(socket.filaImpressao.itens, isEmpty);
  });

  test('mudanca de empresa nao envia a fila de outra conta', () async {
    await guardar();
    final anterior = sync.escopo;
    usuario.setUsuario(UsuarioModelo(id: '2', empresa: '90'));
    conectado = true;
    await sync.configurar();
    await sync.tentarNovamente();
    expect(aplicados, isEmpty);
    expect(await banco.operacoes(anterior), hasLength(1));
  });

  test('carrinho alterado durante a finalizacao nao e apagado nem enfileirado',
      () async {
    final item =
        produto(id: '5', nome: 'Pizza', codigo: '5', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto, (itens) => itens.add(item));
    final diferente =
        produto(id: '8', nome: 'Suco', codigo: '8', computador: 'Cozinha');
    await expectLater(
        sync.guardarPedido(
            contexto: contexto,
            itens: [diferente],
            idMesa: '0',
            idComanda: '4',
            idCliente: '0',
            impressoes: []),
        throwsStateError);
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect((await ArmazenamentoCarrinhos.instancia.listar(contexto)).single.id,
        '5');
  });

  test(
      'ACK de impressao impede recriar fila apos reinicio entre confirmacao e limpeza',
      () async {
    final mensagem =
        jsonEncode({'idRequisicao': 'ack-1', 'tipoImpressao': '1'});
    await socket.filaImpressao.registrar([mensagem]);
    await socket.filaImpressao.confirmar('ack-1');
    await socket.filaImpressao.registrar([mensagem]);
    expect(socket.filaImpressao.itens, isEmpty);
  });

  test('catalogo local permite pesquisa e pagina ainda nao consultadas na rede',
      () async {
    final itens = [
      produto(
              id: '5',
              codigo: '5',
              nome: 'Quatro Queijos',
              computador: 'Cozinha')
          .toMap(),
      produto(id: '50', codigo: '50', nome: 'Atum', computador: 'Cozinha')
          .toMap(),
    ];
    await banco.gravar('catalogo:${sync.escopo}',
        jsonEncode({'produtos': itens, 'detalhes': {}}));
    final resposta =
        await api.cliente.get('produtos/listar.php', queryParameters: {
      'pesquisa': '05',
      'codigo_exato': 'Sim',
      'empresa': '32',
      'categoria': '0',
      'id_usuario': '1',
      'id_cliente': '0',
    });
    expect(resposta.data, hasLength(1));
    expect(resposta.data.single['codigo'], '5');
    final todos = await api.cliente
        .get('produtos/listar_por_categoria.php', queryParameters: {
      'categoria': '0',
      'empresa': '32',
      'id_usuario': '1',
      'pagina': 1,
    });
    expect(todos.data, hasLength(2));
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });

  for (final largura in [320.0, 430.0, 1024.0]) {
    testWidgets('pendencias legiveis na largura $largura', (tester) async {
      tester.view.physicalSize = Size(largura, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        await guardar();
        conectado = true;
        conflito = true;
        await sync.tentarNovamente();
      });
      await tester.pumpWidget(MaterialApp(
          home: MediaQuery(
              data: MediaQueryData(
                  size: Size(largura, 900),
                  textScaler: const TextScaler.linear(1.5)),
              child: PendenciasSincronizacao(sincronizador: sync))));
      await tester.pumpAndSettle();
      expect(find.text('Atendimento encerrado'), findsOneWidget);
      expect(find.text('Sem cebola'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('tela de sincronizacao abre mesmo com pendencia incompleta',
      (tester) async {
    sync.pendencias = [
      {
        'id': 'pendencia-quebrada',
        'atendimento': '104',
        'estado': 'pendente',
        'dados': '{json-invalido',
        'impressoes': '[{"idRequisicao":"p1"}',
      }
    ];

    await tester.pumpWidget(
        MaterialApp(home: PendenciasSincronizacao(sincronizador: sync)));
    await tester.pumpAndSettle();

    expect(find.text('Envio dos pedidos'), findsOneWidget);
    expect(find.text('Atendimento 104'), findsOneWidget);
    expect(
        find.text('Nao foi possivel detalhar os itens salvos neste registro.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
