import 'dart:async';
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
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/impressao_preparo_test.dart' show produto;

class SocketOfflineTeste extends Server {
  final recuperacoes = <bool>[];
  final mensagens = <Map<String, dynamic>>[];
  Completer<void>? tentativaManual;

  @override
  Future<void> processarImpressoesPendentes(
      {bool reconectarAgora = false}) async {
    recuperacoes.add(reconectarAgora);
    if (reconectarAgora) await tentativaManual?.future;
  }

  @override
  bool write(String message) {
    mensagens.add(Map<String, dynamic>.from(jsonDecode(message) as Map));
    return false;
  }
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
  var codigoConflito = 'atendimento_encerrado';
  var mensagemConflito = 'Atendimento encerrado';
  var contratoConflito = true;
  var conflitoAbertura = false;
  Completer<void>? requisicaoPausada;
  Completer<void>? liberarResposta;
  var reciboVendaIncompleto = false;
  var impressaoPersistidaApi = false;
  final aplicados = <String>{};
  final tentativas = <Map<String, dynamic>>[];
  const contexto = ContextoCarrinho(
      empresa: '32', tipo: 'comanda', idAtendimento: '104', idRecurso: '4');

  setUp(() async {
    conectado = false;
    perderResposta = false;
    conflito = false;
    codigoConflito = 'atendimento_encerrado';
    mensagemConflito = 'Atendimento encerrado';
    contratoConflito = true;
    conflitoAbertura = false;
    requisicaoPausada = null;
    liberarResposta = null;
    reciboVendaIncompleto = false;
    impressaoPersistidaApi = false;
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
        .add(InterceptorsWrapper(onRequest: (options, handler) async {
      final rota = CacheConsultas.caminho(options);
      Map<String, dynamic>? pedido;
      if (options.method == 'POST') {
        pedido = Map<String, dynamic>.from(options.data is String
            ? jsonDecode(options.data as String) as Map
            : options.data as Map);
        tentativas.add(pedido);
      }
      if (!conectado) {
        // Simula erro do transporte passando pelo onError do cache offline.
        handler.reject(
            DioException(
                requestOptions: options,
                type: DioExceptionType.connectionError),
            true);
        return;
      }
      if (pedido != null) {
        if (rota.endsWith('inserir_mesa_ocupada.php') ||
            rota.endsWith('inserir_comanda_ocupada.php')) {
          handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'sucesso': true, 'idcomandapedido': '401'}));
          return;
        }
        if ((conflito && pedido['dados']['id_comanda_pedido'] == '104') ||
            (conflitoAbertura && pedido['acao'] == 'abertura')) {
          handler.reject(DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response:
                  Response(requestOptions: options, statusCode: 409, data: {
                if (contratoConflito) ...{
                  'protocolo': 1,
                  'sucesso': false,
                  'codigo': codigoConflito,
                },
                'mensagem': mensagemConflito,
              })));
          return;
        }
        aplicados.add(pedido['id_operacao'] as String);
        if (liberarResposta != null) {
          if (requisicaoPausada?.isCompleted == false) {
            requisicaoPausada!.complete();
          }
          await liberarResposta!.future;
        }
        if (perderResposta) {
          perderResposta = false;
          handler.reject(DioException(
              requestOptions: options, type: DioExceptionType.receiveTimeout));
          return;
        }
        handler
            .resolve(Response(requestOptions: options, statusCode: 200, data: {
          'protocolo': 1,
          'sucesso': true,
          'id_operacao': pedido['id_operacao'],
          if (impressaoPersistidaApi) 'impressao_persistida': true,
          if (pedido['acao'] == 'abertura') ...{
            'id_comanda_pedido': '201',
            'versao_atendimento': 'nova-versao',
            'numeroPedido': '31',
          },
          if (pedido['dados']['id_abertura'] != null) 'numeroPedido': '31',
          if (pedido['acao'] == 'venda' && !reciboVendaIncompleto) ...{
            'idVenda': '301',
            'numeroPedido': '32'
          },
          if (pedido['acao'] == 'editar_item') ...{
            'id_itens_venda': pedido['dados']['id_itens_venda'],
            'numeroPedido': '31',
          },
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
          'abertura_offline': 1,
          'caixa_id': '0',
          'recursos': {
            for (final tipo in ['mesa', 'comanda'])
              '$tipo:5': {
                'id': '5',
                'nome': '5',
                'codigo': '5',
                'ativo': 'Sim',
                'livre': true,
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
    await sync.aguardarPreparacaoOffline();
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

  test('preparo assumido pela API nao cria outra via no socket do garcom',
      () async {
    await guardar();
    conectado = true;
    impressaoPersistidaApi = true;
    await sync.tentarNovamente();
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(socket.filaImpressao.itens, isEmpty);
    expect(socket.mensagens.where((e) => e['tipo'] == 'PreparoPendente'),
        hasLength(1));
    await sync.tentarNovamente();
    expect(aplicados, hasLength(1));
  });

  test('API assume preparo e conserva comprovante de consumo no envio local',
      () async {
    await guardar();
    final operacao = (await banco.operacoes(sync.escopo)).single;
    final impressoes =
        List<String>.from(jsonDecode(operacao['impressoes'] as String));
    impressoes
        .add(jsonEncode({'idRequisicao': 'consumo-104', 'tipoImpressao': '2'}));
    await banco.atualizarOperacao(
        operacao['id'] as String, {'impressoes': jsonEncode(impressoes)});
    conectado = true;
    impressaoPersistidaApi = true;
    await sync.tentarNovamente();
    expect(socket.filaImpressao.itens.single.id, 'consumo-104');
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test('falha na API nao impede recuperacao automatica do canal da cozinha',
      () async {
    await sync.sincronizar();
    expect(sync.online, isFalse);
    expect(socket.recuperacoes, [false]);
    expect(sync.sincronizando, isFalse);
  });

  test('trocar conta nao mostra horario da sincronizacao anterior', () async {
    sync.ultimaAtualizacao = DateTime(2026, 9, 12);
    usuario.setUsuario(UsuarioModelo(id: '2', empresa: '33'));
    await sync.configurar();
    expect(sync.ultimaAtualizacao, isNull);
  });

  test('tentar novamente recupera impressao sem API e agrupa toques repetidos',
      () async {
    socket.tentativaManual = Completer<void>();
    final estados = <bool>[];
    sync.addListener(() => estados.add(sync.sincronizando));
    final primeira = sync.tentarNovamente();
    final segunda = sync.tentarNovamente();
    expect(segunda, same(primeira));
    expect(sync.sincronizando, isTrue);
    await sync.sincronizar();
    expect(socket.recuperacoes.where((imediata) => imediata), hasLength(1));
    expect(sync.online, isFalse);
    expect(sync.sincronizando, isTrue);
    socket.tentativaManual!.complete();
    await primeira;
    expect(sync.sincronizando, isFalse);
    expect(estados.first, isTrue);
    expect(estados.last, isFalse);
  });

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

  test('pedido salvo durante outro envio segue sem aguardar o temporizador',
      () async {
    await guardar();
    final primeiro = (await banco.operacoes(sync.escopo)).single;
    await banco.atualizarOperacao(primeiro['id'] as String, {'proxima': 0});

    conectado = true;
    requisicaoPausada = Completer<void>();
    liberarResposta = Completer<void>();
    final envio = sync.enviarPendentes();
    await requisicaoPausada!.future;

    final item =
        produto(id: '8', nome: 'Suco', codigo: '8', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto, (itens) => itens.add(item));
    await sync.guardarPedido(
        contexto: contexto,
        itens: [item],
        idMesa: '0',
        idComanda: '4',
        idCliente: '0',
        impressoes: []);

    liberarResposta!.complete();
    await envio;

    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(aplicados, hasLength(2));
  });

  for (final tipo in ['mesa', 'comanda']) {
    test('servidor antigo ainda permite abertura online de $tipo', () async {
      await banco.gravar('estado:${sync.escopo}', '{}');
      Sincronizador.instancia = sync;
      conectado = true;
      final id = tipo == 'mesa'
          ? (await ServicoMesas(api, usuario).inserirMesaOcupada('5', '0', ''))
              .idcomandapedido
          : (await ServicoComandas(api, usuario)
                  .inserirComandaOcupada('5', '0', '0', ''))
              .idcomandapedido;
      expect(id, '401');
      expect(await banco.operacoes(sync.escopo), isEmpty);
      expect(tentativas.single.containsKey('acao'), isFalse);
    });

    test(
        'abre $tipo offline, permite produtos e imprime apos confirmar abertura',
        () async {
      Sincronizador.instancia = sync;
      final id = tipo == 'mesa'
          ? (await ServicoMesas(api, usuario)
                  .inserirMesaOcupada('5', '0', 'Bruno'))
              .idcomandapedido
          : (await ServicoComandas(api, usuario)
                  .inserirComandaOcupada('5', '0', '0', 'Bruno'))
              .idcomandapedido!;
      final tela = await ServicoCardapio(api, usuario)
          .listarPorId(id, TipoCardapio.values.byName(tipo), 'Não');
      expect(tela.id, id);
      expect(tela.observacaoDoPedido, 'Bruno');
      final alvo = ContextoCarrinho(
          empresa: '32', tipo: tipo, idAtendimento: id, idRecurso: '5');
      final item =
          produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
      await ArmazenamentoCarrinhos.instancia
          .alterar(alvo, (itens) => itens.add(item));
      await sync.guardarPedido(
          contexto: alvo,
          itens: [item],
          idMesa: tipo == 'mesa' ? '5' : '0',
          idComanda: tipo == 'comanda' ? '5' : '0',
          idCliente: '0',
          impressoes: [
            jsonEncode({
              'idRequisicao': 'nova-$tipo',
              'tipoImpressao': '1',
              'numeroPedido': ''
            })
          ]);
      await sync.enviarPendentes();
      expect(await banco.operacoes(sync.escopo), hasLength(2));
      expect(socket.filaImpressao.itens, isEmpty);
      final lista = await AtendimentosLocais(banco, sync.escopo).projetarLista([
        {
          'titulo': 'Livres',
          tipo == 'mesa' ? 'mesas' : 'comandas': [
            {
              'id': '5',
              'nome': '5',
              'codigo': '5',
              'ativo': 'Sim',
              tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada': false
            }
          ]
        }
      ], tipo, '');
      expect(lista.first['titulo'], 'Ocupadas');
      expect(
          lista.first[tipo == 'mesa' ? 'mesas' : 'comandas']
              .single['idComandaPedido'],
          id);
      conectado = true;
      await sync.tentarNovamente();
      expect(await banco.operacoes(sync.escopo), isEmpty);
      expect(aplicados, hasLength(2));
      expect(socket.filaImpressao.itens.single.dados['numeroPedido'], '31');
      final enviados = tentativas.where((p) => p['acao'] == 'produtos');
      expect(enviados.single['dados']['id_abertura'], id.substring(6));
    });
  }

  test(
      'itens preservam mesa e comanda da abertura, mesmo com argumentos antigos da tela',
      () async {
    final id = await sync.abrirAtendimento(
        tipo: 'comanda', idComanda: '5', idMesa: '5');
    await guardar(
        alvo: ContextoCarrinho(
            empresa: '32', tipo: 'comanda', idAtendimento: id, idRecurso: '5'));
    final fila = await banco.operacoes(sync.escopo);
    final dados = AtendimentosLocais.dados(fila.last);
    expect(dados['id_mesa'], '5');
    expect(dados['id_comanda'], '5');
  });

  test('abertura confirmada continua visivel se a lista ainda esta antiga',
      () async {
    final id = await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5');
    await sync.enviarPendentes();
    conectado = true;
    await banco.atualizarOperacao(id.substring(6), {'proxima': 0});
    await sync.enviarPendentes();
    final locais = AtendimentosLocais(banco, sync.escopo);
    final grupos = [
      {
        'titulo': 'Livres',
        'comandas': [
          {'id': '5', 'nome': '5', 'comandaOcupada': false}
        ]
      }
    ];
    final lista = await locais.projetarLista(grupos, 'comanda', '');
    expect(lista.first['comandas'].single['idComandaPedido'], id);
    await expectLater(sync.abrirAtendimento(tipo: 'comanda', idComanda: '5'),
        throwsStateError);
    final estado =
        jsonDecode((await banco.ler('estado:${sync.escopo}'))!) as Map;
    estado['recursos']['comanda:5']['versao'] = 'abriu-fechou';
    await banco.gravar('estado:${sync.escopo}', jsonEncode(estado));
    final encerrada = await locais.projetarLista(grupos, 'comanda', '');
    expect(encerrada.single['titulo'], 'Livres');
    expect((await locais.detalhe(id))['status'], 'Fechamento');
  });

  test(
      'recebimento usa id confirmado e bloqueia somente alteracao realmente pendente',
      () async {
    final idOperacao = BancoLocal.novoId();
    final idLocal = 'local:$idOperacao';
    await banco.db.insert('operacoes', {
      'id': idOperacao,
      'escopo': sync.escopo,
      'atendimento': idLocal,
      'acao': 'abertura',
      'estado': 'concluido',
      'dados': jsonEncode({'tipo': 'comanda', 'id_comanda': '5'}),
      'impressoes': '[]',
      'destino': 'cozinha',
      'criado': 1,
      'resposta': jsonEncode({'id_comanda_pedido': '139'}),
    });
    final locais = AtendimentosLocais(banco, sync.escopo);

    expect(await locais.idServidorParaRecebimento(idLocal), '139');

    final idProduto = BancoLocal.novoId();
    await banco.db.insert('operacoes', {
      'id': idProduto,
      'escopo': sync.escopo,
      'atendimento': idLocal,
      'acao': 'produtos',
      'estado': 'pendente',
      'dados': '{}',
      'impressoes': '[]',
      'destino': 'cozinha',
      'criado': 2,
    });
    await expectLater(
      locais.idServidorParaRecebimento(idLocal),
      throwsA(isA<StateError>().having(
        (erro) => erro.message,
        'mensagem',
        contains('ainda não confirmado'),
      )),
    );

    // O servidor já confirmou; faltar apenas a impressão local não pode
    // impedir o recebimento no caixa.
    await banco.atualizarOperacao(idProduto, {'estado': 'registrado'});
    expect(await locais.idServidorParaRecebimento(idLocal), '139');
  });

  test(
      'abertura conflitante preserva itens, nao imprime e arquivar nao libera dependentes',
      () async {
    final id = await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5');
    await guardar(
        alvo: ContextoCarrinho(
            empresa: '32', tipo: 'comanda', idAtendimento: id, idRecurso: '5'));
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
    expect(
        AtendimentosLocais.dados(
            (await banco.operacoes(sync.escopo)).single)['produtos'],
        hasLength(1));
  });

  test('duplo toque nao abre duas comandas locais no mesmo recurso', () async {
    final resultados = await Future.wait([0, 1].map((_) async {
      try {
        return await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5');
      } on StateError {
        return null;
      }
    }));
    expect(resultados.whereType<String>(), hasLength(1));
    await sync.enviarPendentes();
    expect(await banco.operacoes(sync.escopo), hasLength(1));
  });

  test(
      'reinicio e resposta perdida da abertura preservam dependencia e identidade',
      () async {
    final id = await sync.abrirAtendimento(tipo: 'comanda', idComanda: '5');
    await guardar(
        alvo: ContextoCarrinho(
            empresa: '32', tipo: 'comanda', idAtendimento: id, idRecurso: '5'));
    conectado = true;
    perderResposta = true;
    await sync.tentarNovamente();
    expect(socket.filaImpressao.itens, isEmpty);
    sync.dispose();
    await banco.db.close();
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    sync = Sincronizador(api, usuario, socket, banco: banco);
    await sync.configurar();
    await sync.tentarNovamente();
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(aplicados, hasLength(2));
    expect(socket.filaImpressao.itens, hasLength(1));
  });

  test('venda offline e pagamento seguinte sobrevivem sem duplicar impressao',
      () async {
    const alvo =
        ContextoCarrinho(empresa: '32', tipo: 'balcao', idAtendimento: '0');
    final item =
        produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(alvo, (itens) => itens.add(item));
    final id = await sync.guardarVenda(contexto: alvo, itens: [
      item
    ], dados: {
      'produtos': [item.toMap()],
      'empresa': '32',
      'id_usuario': '1',
      'valor_lancamento': '10'
    }, impressoes: [
      jsonEncode({'idRequisicao': 'venda-1', 'tipoImpressao': '1'})
    ]);
    await sync.guardarPagamentoVenda(
        id, {'empresa': '32', 'id_usuario': '1', 'valor_lancamento': '20'});
    await sync.enviarPendentes();
    expect(await ArmazenamentoCarrinhos.instancia.listar(alvo), isEmpty);
    expect(await banco.operacoes(sync.escopo), hasLength(2));
    conectado = true;
    await sync.tentarNovamente();
    expect(aplicados, hasLength(2));
    expect(socket.filaImpressao.itens.single.dados['numeroPedido'], '32');
    expect(socket.filaImpressao.itens.single.dados['comanda'], 'Balcão 301');
  });

  test('venda sem identidade confirmada nao imprime e repete o mesmo recibo',
      () async {
    const alvo =
        ContextoCarrinho(empresa: '32', tipo: 'balcao', idAtendimento: '0');
    final item =
        produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(alvo, (itens) => itens.add(item));
    await sync.guardarVenda(contexto: alvo, itens: [
      item
    ], dados: {
      'produtos': [item.toMap()],
      'empresa': '32',
      'id_usuario': '1'
    }, impressoes: [
      jsonEncode({'idRequisicao': 'venda-incompleta', 'tipoImpressao': '1'})
    ]);
    await sync.enviarPendentes();
    conectado = true;
    reciboVendaIncompleto = true;
    await sync.tentarNovamente();
    expect(socket.filaImpressao.itens, isEmpty);
    expect(await banco.operacoes(sync.escopo), hasLength(1));
    reciboVendaIncompleto = false;
    await sync.tentarNovamente();
    expect(aplicados, hasLength(1));
    expect(socket.filaImpressao.itens, hasLength(1));
  });

  test('arquivar venda original nao libera pagamentos dependentes', () async {
    const alvo =
        ContextoCarrinho(empresa: '32', tipo: 'balcao', idAtendimento: '0');
    final item =
        produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(alvo, (itens) => itens.add(item));
    final id = await sync.guardarVenda(contexto: alvo, itens: [
      item
    ], dados: {
      'produtos': [item.toMap()],
      'empresa': '32',
      'id_usuario': '1'
    }, impressoes: []);
    await sync.guardarPagamentoVenda(id, {'empresa': '32', 'id_usuario': '1'});
    await sync.enviarPendentes();
    final original = (await banco.operacoes(sync.escopo)).first;
    await banco
        .atualizarOperacao(original['id'] as String, {'estado': 'conflito'});
    await sync.arquivarConflito(original['id'] as String);
    conectado = true;
    await sync.tentarNovamente();
    expect(aplicados, isEmpty);
    expect((await banco.operacoes(sync.escopo)).single['estado'], 'conflito');
  });

  test('venda preparada por outra conta nao limpa o carrinho nem entra na fila',
      () async {
    const alvo =
        ContextoCarrinho(empresa: '32', tipo: 'balcao', idAtendimento: '0');
    final item =
        produto(id: '5', codigo: '5', nome: 'Pizza', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia
        .alterar(alvo, (itens) => itens.add(item));
    await expectLater(
        sync.guardarVenda(
            contexto: alvo,
            itens: [item],
            dados: {'empresa': '32', 'id_usuario': 'outro'},
            impressoes: []),
        throwsStateError);
    expect(await ArmazenamentoCarrinhos.instancia.listar(alvo), hasLength(1));
    expect(await banco.operacoes(sync.escopo), isEmpty);
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

  test('reenviar para servidor libera recusa de produto manualmente', () async {
    await guardar();
    conectado = true;
    conflito = true;
    codigoConflito = 'produto_invalido';
    mensagemConflito = 'Uma opcao do produto foi removida ou alterada.';
    await sync.tentarNovamente();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    expect(pendente['estado'], 'conflito');
    final tentativasAntes = tentativas.length;

    conflito = false;
    await sync.reenviarParaServidor(pendente['id'] as String);

    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(tentativas.length, greaterThan(tentativasAntes));
    expect(aplicados, hasLength(1));
    expect(socket.filaImpressao.itens, hasLength(1));
  });

  test('voltar pedido recusado restaura itens e arquiva pendencia', () async {
    await guardar();
    conectado = true;
    conflito = true;
    codigoConflito = 'produto_invalido';
    mensagemConflito = 'Uma opcao do produto foi removida ou alterada.';
    await sync.tentarNovamente();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);

    await sync.voltarPedidoParaCarrinho(pendente['id'] as String);

    expect(await banco.operacoes(sync.escopo), isEmpty);
    final itens = await ArmazenamentoCarrinhos.instancia.listar(contexto);
    expect(itens, hasLength(1));
    expect(itens.single.observacao, 'Sem cebola');
    final historico = await banco.db.query('operacoes');
    expect(historico.single['estado'], 'arquivado');
    expect(aplicados, isEmpty);
    expect(socket.filaImpressao.itens, isEmpty);
  });

  test('resposta perdida impede voltar ao carrinho e conserva recibo incerto',
      () async {
    conectado = true;
    perderResposta = true;
    await guardar();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    expect(aplicados, {pendente['id']});
    expect(pendente['tentativas'], 1);

    await expectLater(sync.voltarPedidoParaCarrinho(pendente['id'] as String),
        throwsStateError);

    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);
    expect((await banco.operacoes(sync.escopo)).single, pendente);
    expect(socket.filaImpressao.itens, isEmpty);
    await sync.reenviarParaServidor(pendente['id'] as String);
    expect(aplicados, hasLength(1));
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  test('pedido registrado aguardando impressao nao volta ao carrinho',
      () async {
    await guardar();
    final original = (await banco.operacoes(sync.escopo)).single;
    await banco.atualizarOperacao(original['id'] as String, {
      'estado': 'registrado',
      'resposta': jsonEncode({
        'protocolo': 1,
        'sucesso': true,
        'id_operacao': original['id'],
      }),
    });
    final registrado = (await banco.operacoes(sync.escopo)).single;
    final requisicoesAntes = tentativas.length;

    await expectLater(sync.voltarPedidoParaCarrinho(original['id'] as String),
        throwsStateError);

    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);
    expect((await banco.operacoes(sync.escopo)).single, registrado);
    expect(tentativas.length, requisicoesAntes);
  });

  test('reenvio incerto conserva payload e contador ja utilizado', () async {
    await guardar();
    final op = (await banco.operacoes(sync.escopo)).single;
    final dados = Map<String, dynamic>.from(jsonDecode(op['dados'] as String));
    final itens = dados['produtos'] as List;
    (itens.single as Map)['observacao'] = 'Observacao\nantiga';
    final payloadOriginal = jsonEncode(dados);
    await banco.atualizarOperacao(op['id'] as String, {
      'dados': payloadOriginal,
      'tentativas': 3,
      'proxima': 9999999999999,
    });

    await sync.reenviarParaServidor(op['id'] as String);

    final depois = (await banco.operacoes(sync.escopo)).single;
    expect(depois['id'], op['id']);
    expect(depois['dados'], payloadOriginal);
    expect(depois['tentativas'], 4);
    expect(depois['estado'], 'pendente');
    expect(tentativas.last['id_operacao'], op['id']);
    expect(tentativas.last['dados'], dados);
    await expectLater(
        sync.voltarPedidoParaCarrinho(op['id'] as String), throwsStateError);
  });

  test('erro HTTP sem contrato nao libera edicao de envio incerto', () async {
    await guardar();
    conectado = true;
    conflito = true;
    contratoConflito = false;
    codigoConflito = 'produto_invalido';
    mensagemConflito = 'Falha intermediaria ao consultar o pedido';
    await sync.tentarNovamente();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    expect(pendente['estado'], 'pendente');
    expect(pendente['tentativas'], greaterThan(0));
    await expectLater(sync.voltarPedidoParaCarrinho(pendente['id'] as String),
        throwsStateError);
    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);
  });

  test('recuperacao espera HTTP em voo e nao copia pedido ja confirmado',
      () async {
    conectado = true;
    requisicaoPausada = Completer<void>();
    liberarResposta = Completer<void>();
    addTearDown(() {
      if (!liberarResposta!.isCompleted) liberarResposta!.complete();
    });
    final envio = guardar();
    await requisicaoPausada!.future;
    final pendente = (await banco.operacoes(sync.escopo)).single;
    var recuperacaoTerminou = false;
    final recuperacao = expectLater(
        sync
            .voltarPedidoParaCarrinho(pendente['id'] as String)
            .whenComplete(() => recuperacaoTerminou = true),
        throwsStateError);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(recuperacaoTerminou, isFalse);
    liberarResposta!.complete();
    await envio;
    await recuperacao;
    expect(aplicados, hasLength(1));
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);
  });

  test(
      'falha ao arquivar recuperacao reverte carrinho e permite uma unica copia',
      () async {
    await guardar();
    conectado = true;
    conflito = true;
    codigoConflito = 'produto_invalido';
    mensagemConflito = 'Produto precisa de revisao';
    await sync.tentarNovamente();
    final pendente = (await banco.operacoes(sync.escopo)).single;
    final id = pendente['id'] as String;
    await banco.db.execute(
        "CREATE TEMP TRIGGER simular_falha_recuperacao BEFORE UPDATE ON operacoes "
        "WHEN NEW.estado = 'arquivado' BEGIN SELECT RAISE(ABORT, 'disco cheio'); END");

    await expectLater(
        sync.voltarPedidoParaCarrinho(id), throwsA(isA<DatabaseException>()));
    expect((await banco.operacoes(sync.escopo)).single, pendente);
    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);
    await banco.db.execute('DROP TRIGGER simular_falha_recuperacao');

    final resultados = await Future.wait(List.generate(2, (_) async {
      try {
        await sync.voltarPedidoParaCarrinho(id);
        return true;
      } on StateError {
        return false;
      }
    }));
    expect(resultados.where((sucesso) => sucesso), hasLength(1));
    expect(await banco.operacoes(sync.escopo), isEmpty);
    final itens = await ArmazenamentoCarrinhos.instancia.listar(contexto);
    expect(itens, hasLength(1));
    expect(itens.single.quantidade, 2);
    expect(aplicados, isEmpty);
    expect(socket.filaImpressao.itens, isEmpty);
  });

  test(
      'conta encerrada bloqueia reenvio e recuperacao mas libera outras comandas',
      () async {
    await guardar();
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
    expect(pendentes, hasLength(2));
    final encerrado = pendentes.firstWhere((op) => op['estado'] == 'conflito');
    expect(encerrado['codigo_erro'], 'atendimento_encerrado');
    final requisicoesAntes = tentativas.length;
    final id = encerrado['id'] as String;

    await expectLater(sync.reenviarParaServidor(id), throwsStateError);
    await expectLater(sync.voltarPedidoParaCarrinho(id), throwsStateError);
    expect(tentativas.length, requisicoesAntes);
    expect(await ArmazenamentoCarrinhos.instancia.listar(contexto), isEmpty);
    expect(aplicados, hasLength(1));
    expect(socket.filaImpressao.itens.single.id, 'impressao-106');

    await sync.arquivarConflito(id);
    final restante = (await banco.operacoes(sync.escopo)).single;
    expect(restante['estado'], 'conflito');
    expect(restante['codigo_erro'], 'origem_nao_confirmada');
    await expectLater(
        sync.reenviarParaServidor(restante['id'] as String), throwsStateError);
    await sync.arquivarConflito(restante['id'] as String);
    await sync.tentarNovamente();
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(tentativas.length, requisicoesAntes);
    expect(
        (await banco.db.query('operacoes')).where(
            (op) => op['atendimento'] == '104' && op['estado'] == 'arquivado'),
        hasLength(2));
  });

  test('observacao livre nao e enviada como opcao comercial', () async {
    final observacao = '${'Asa ' * 70}\nsem cortar';
    final item = produto(id: '5', nome: 'Pizza', codigo: '5')
      ..observacao = ''
      ..opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
          id: 11,
          titulo: 'Observação',
          tipo: 7,
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(id: '0', nome: observacao, valor: '0'),
          ],
        )
      ];
    await ArmazenamentoCarrinhos.instancia
        .alterar(contexto, (itens) => itens.add(item));
    await sync.guardarPedido(
        contexto: contexto,
        itens: [item],
        idMesa: '0',
        idComanda: '4',
        idCliente: '0',
        impressoes: []);

    conectado = true;
    await sync.tentarNovamente();

    final enviado =
        tentativas.lastWhere((pedido) => pedido['acao'] == 'produtos');
    final produtoEnviado = (enviado['dados']['produtos'] as List).single as Map;
    expect((produtoEnviado['observacao'] as String).contains('\n'), isFalse);
    expect((produtoEnviado['observacao'] as String).runes.length,
        lessThanOrEqualTo(200));
    final opcoes = produtoEnviado['opcoesPacotesListaFinal'] as List;
    expect(opcoes.where((opcao) {
      final mapa = opcao as Map;
      return mapa['titulo'] == 'Observação' || mapa['id'].toString() == '12';
    }), isEmpty);
  });

  test('edicao finalizada fica duravel e imprime somente item confirmado',
      () async {
    final item =
        produto(id: '5', nome: 'Pizza', codigo: '5', computador: 'Cozinha')
          ..iditensvenda = '900'
          ..quantidade = 3
          ..observacao = 'Bem assada';

    await sync.guardarEdicaoProdutoFinalizado(
      tipo: 'comanda',
      idAtendimento: '104',
      versaoAtendimento: 'versao-original',
      idItemVenda: '900',
      produto: item,
      idMesa: '0',
      idComanda: '4',
      idCliente: '0',
      impressoes: [
        jsonEncode({
          'idRequisicao': 'edicao-900',
          'tipoImpressao': '1',
          'idEmpresa': '32',
          'produtos': [item.toMap()],
        })
      ],
    );

    final fila = await banco.operacoes(sync.escopo);
    expect(fila, hasLength(1));
    expect(fila.single['acao'], 'editar_item');
    expect(fila.single['estado'], 'pendente');
    expect(socket.filaImpressao.itens, isEmpty);

    final salvo = jsonDecode(fila.single['dados'] as String);
    expect(salvo['produto']['observacao'], 'Bem assada');
    expect(salvo['produto']['quantidade'], 3);
    expect(salvo['id_itens_venda'], '900');

    conectado = true;
    await sync.tentarNovamente();

    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(tentativas.last['acao'], 'editar_item');
    expect(socket.filaImpressao.itens, hasLength(1));
    expect(socket.filaImpressao.itens.single.id, 'edicao-900');
  });

  test('reenviar conflito antigo normaliza observacao antes de enviar',
      () async {
    final idOperacao = BancoLocal.novoId();
    const observacao = 'Observacao antiga salva apenas no pacote';
    final item = produto(id: '5', nome: 'Pizza', codigo: '5')
      ..observacao = ''
      ..opcoesPacotesListaFinal = [
        ModeloOpcoesPacotes(
          id: 11,
          titulo: 'Observação',
          tipo: 7,
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(id: '0', nome: observacao, valor: '0'),
          ],
        )
      ];
    await banco.db.insert('operacoes', {
      'id': idOperacao,
      'escopo': sync.escopo,
      'atendimento': '104',
      'acao': 'produtos',
      'estado': 'conflito',
      'dados': jsonEncode({
        'produtos': [item.toMap()],
        'id_comanda_pedido': '104',
        'id_comanda': '4',
        'id_mesa': '0',
        'id_cliente': '0',
        'tipo': 'comanda',
        'empresa': '32',
        'id_usuario': '1',
      }),
      'impressoes': '[]',
      'destino': '',
      'criado': DateTime.now().millisecondsSinceEpoch,
      'tentativas': 3,
      'proxima': 999999,
    });
    await sync.configurar();

    conectado = true;
    await sync.reenviarParaServidor(idOperacao);

    final enviado =
        tentativas.lastWhere((pedido) => pedido['acao'] == 'produtos');
    final produtoEnviado = (enviado['dados']['produtos'] as List).single as Map;
    expect(produtoEnviado['observacao'], observacao);
    expect(produtoEnviado['opcoesPacotesListaFinal'], isEmpty);
    expect(await banco.operacoes(sync.escopo), isEmpty);
  });

  testWidgets('card de conflito mostra acoes de recuperacao', (tester) async {
    sync.pendencias = [
      {
        'id': 'operacao-pendente',
        'acao': 'produtos',
        'atendimento': '104',
        'estado': 'conflito',
        'erro': 'Uma opcao do produto foi removida ou alterada.',
        'dados': jsonEncode({
          'produtos': [
            {'nome': 'Outras Pizzas', 'quantidade': 1}
          ],
        }),
        'impressoes': '[]',
      }
    ];

    await tester.pumpWidget(
        MaterialApp(home: PendenciasSincronizacao(sincronizador: sync)));

    final reenviar =
        find.widgetWithText(FilledButton, 'Reenviar para o Servidor');
    expect(reenviar, findsOneWidget);
    expect(
        find.widgetWithText(
            OutlinedButton, 'Voltar esse Pedido para o Carrinho'),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Excluir da sincronizacao'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
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

  test('atualizar banco v1 preserva pedido e adiciona codigo do conflito',
      () async {
    await guardar();
    final pedido =
        Map<String, Object?>.from((await banco.operacoes(sync.escopo)).single)
          ..remove('codigo_erro');
    final caminho = '${pasta.path}/versao-anterior.db';
    final anterior = await databaseFactoryFfi.openDatabase(caminho,
        options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async {
              await db.execute('CREATE TABLE operacoes ('
                  'id TEXT PRIMARY KEY, escopo TEXT NOT NULL, '
                  'atendimento TEXT NOT NULL, acao TEXT NOT NULL, '
                  'estado TEXT NOT NULL, dados TEXT NOT NULL, '
                  'impressoes TEXT NOT NULL, destino TEXT NOT NULL, '
                  'criado INTEGER NOT NULL, tentativas INTEGER NOT NULL DEFAULT 0, '
                  'proxima INTEGER NOT NULL DEFAULT 0, erro TEXT, resposta TEXT)');
            }));
    await anterior.insert('operacoes', pedido);
    await anterior.close();

    final atualizado =
        await BancoLocal.abrir(factory: databaseFactoryFfi, path: caminho);
    try {
      expect(await atualizado.db.getVersion(), 2);
      final preservado = (await atualizado.operacoes(sync.escopo)).single;
      expect(preservado, {...pedido, 'codigo_erro': null});
      await atualizado.atualizarOperacao(pedido['id'] as String, {
        'estado': 'conflito',
        'codigo_erro': 'atendimento_encerrado',
      });
      expect((await atualizado.operacoes(sync.escopo)).single['codigo_erro'],
          'atendimento_encerrado');
    } finally {
      await atualizado.db.close();
    }
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

  test('pesquisa offline encontra acai e agua sem acentos', () async {
    await banco.gravar(
        'catalogo:${sync.escopo}',
        jsonEncode({
          'produtos': [
            produto(
                    id: '5',
                    codigo: '5',
                    nome: 'Açaí especial',
                    computador: 'Cozinha')
                .toMap(),
            produto(
                    id: '6',
                    codigo: '6',
                    nome: 'Água com gás',
                    computador: 'Bar')
                .toMap(),
          ],
          'detalhes': {},
        }));
    for (final (termo, id) in [('ACAI', '5'), ('agua', '6')]) {
      final resposta =
          await api.cliente.get('produtos/listar.php', queryParameters: {
        'pesquisa': termo,
        'empresa': '32',
        'categoria': '0',
        'id_usuario': '1',
        'id_cliente': '0',
      });
      expect(resposta.data, hasLength(1));
      expect(resposta.data.single['id'], id);
    }
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
        await sync.aguardarPreparacaoOffline();
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
      expect(find.text('Reenviar para o Servidor'), findsNothing);
      expect(find.text('Voltar esse Pedido para o Carrinho'), findsNothing);
      expect(find.text('Excluir da sincronizacao'), findsOneWidget);
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
