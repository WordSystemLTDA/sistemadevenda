import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/impressao_preparo_test.dart' show produto;

class _SocketPreparacao extends Server {
  @override
  Future<void> processarImpressoesPendentes(
      {bool reconectarAgora = false}) async {}

  @override
  bool write(String message) => false;
}

class _ApiPreparacao implements HttpClientAdapter {
  final chamadas = <RequestOptions>[];
  final detalheIniciado = Completer<void>();
  Completer<void>? liberarDetalhe;
  final pagamentoIniciado = Completer<void>();
  Completer<void>? liberarPagamentos;
  int versaoPagamentos = 1;
  bool falharDetalhe = false;
  List<Map<String, dynamic>> produtos = [
    {'id': '5', 'nome': 'Produto', 'valorVenda': '10.00'},
  ];

  int quantidade(String rota) =>
      chamadas.where((c) => CacheConsultas.caminho(c) == rota).length;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    final rota = CacheConsultas.caminho(options);
    if (rota == 'tela_nfe_saida/listar_bancos.php') {
      final versao = versaoPagamentos;
      if (!pagamentoIniciado.isCompleted) pagamentoIniciado.complete();
      await liberarPagamentos?.future;
      return _json([
        {'id': '1', 'nome': 'Banco $versao'}
      ]);
    }
    if (rota == 'sincronizacao/estado.php') {
      return _json({
        'protocolo': 1,
        'sucesso': true,
        'atendimentos': {
          '104': {'id': '104', 'versao': 'original', 'status': 'Andamento'},
        },
      });
    }
    if (rota == 'sincronizacao/operacao.php') {
      final dados = options.data is String
          ? jsonDecode(options.data as String) as Map
          : options.data as Map;
      return _json({
        'protocolo': 1,
        'sucesso': true,
        'id_operacao': dados['id_operacao'],
        'impressao_persistida': true,
      });
    }
    if (rota == 'produtos/listar_por_categoria.php') return _json(produtos);
    if (rota == 'produtos/listar_por_id.php') {
      if (options.extra['preparacaoOffline'] == true) {
        if (!detalheIniciado.isCompleted) detalheIniciado.complete();
        await liberarDetalhe?.future;
        if (falharDetalhe) {
          throw DioException(
              requestOptions: options, type: DioExceptionType.connectionError);
        }
      }
      return _json({
        'id': options.uri.queryParameters['id'],
        'nome': 'Produto',
        'valorVenda':
            options.extra['preparacaoOffline'] == true ? '10.00' : '17.00',
        'opcoesPacotes': [],
      });
    }
    return _json(rota == 'config_bigchef/listar.php' ? {} : []);
  }

  ResponseBody _json(Object dados) => ResponseBody.fromString(
        jsonEncode(dados),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late _SocketPreparacao socket;
  late _ApiPreparacao transporte;
  late Sincronizador sync;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'}),
    });
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    BancoLocal.instancia = banco;
    api = DioCliente();
    transporte = _ApiPreparacao();
    api.cliente.httpClientAdapter = transporte;
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32', nome: 'Garcom'));
    socket = _SocketPreparacao();
    sync = Sincronizador(api, usuario, socket, banco: banco);
    await sync.configurar();
  });

  tearDown(() async {
    if (transporte.liberarPagamentos?.isCompleted == false) {
      transporte.liberarPagamentos!.complete();
    }
    if (transporte.liberarDetalhe?.isCompleted == false) {
      transporte.liberarDetalhe!.complete();
    }
    await sync.aguardarPreparacaoOffline();
    await sync.enviarPendentes();
    sync.dispose();
    socket.dispose();
    usuario.dispose();
    api.cliente.close(force: true);
    BancoLocal.instancia = null;
    await banco.db.close();
  });

  Future<String> incluirPedidoPendente() async {
    final id = BancoLocal.novoId();
    await banco.db.insert('operacoes', {
      'id': id,
      'escopo': sync.escopo,
      'atendimento': '104',
      'acao': 'produtos',
      'estado': 'pendente',
      'dados': jsonEncode({
        'empresa': '32',
        'id_usuario': '1',
        'id_comanda_pedido': '104',
        'versao_atendimento': 'original',
        'tipo': 'comanda',
        'id_comanda': '4',
        'id_mesa': '0',
        'produtos': [produto(id: '5', nome: 'Produto', codigo: '5').toMap()],
      }),
      'impressoes': '[]',
      'destino': 'cozinha:9980',
      'criado': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }

  test('detalhe lento nao bloqueia estado, conclusao do ciclo nem novo pedido',
      () async {
    transporte.liberarDetalhe = Completer<void>();
    await sync.sincronizar().timeout(const Duration(seconds: 3));
    await transporte.detalheIniciado.future.timeout(const Duration(seconds: 3));
    expect(sync.sincronizando, isFalse);
    expect(sync.online, isTrue);
    expect(await banco.ler('catalogo:${sync.escopo}'), isNull);

    final id = await incluirPedidoPendente();
    await sync.sincronizar().timeout(const Duration(seconds: 3));

    expect(transporte.liberarDetalhe!.isCompleted, isFalse);
    expect(transporte.quantidade('sincronizacao/estado.php'), 2);
    expect(transporte.quantidade('sincronizacao/operacao.php'), 1);
    expect(await banco.operacoes(sync.escopo), isEmpty);
    final operacao =
        await banco.db.query('operacoes', where: 'id = ?', whereArgs: [id]);
    expect(operacao.single['estado'], 'concluido');

    transporte.liberarDetalhe!.complete();
    await sync.aguardarPreparacaoOffline();
    expect(sync.catalogoPronto, isTrue);
  });

  test('estado igual nao redesenha telas nem repete listas e bancos preparados',
      () async {
    transporte.produtos.single['detalhesCompletos'] = true;
    var atualizacoes = 0;
    sync.aoAtualizarTelas = () => atualizacoes++;
    await sync.sincronizar();
    await sync.aguardarPreparacaoOffline();
    final totalConsultas = transporte.chamadas.length;
    expect(atualizacoes, 1);
    expect(sync.catalogoPronto, isTrue);
    expect(transporte.quantidade('tela_nfe_saida/listar_bancos.php'), 1);
    expect(transporte.quantidade('comandas/listar.php'), 1);

    await sync.sincronizar();
    await sync.aguardarPreparacaoOffline();

    expect(atualizacoes, 1);
    expect(transporte.chamadas.length, totalConsultas + 1);
    expect(transporte.quantidade('sincronizacao/estado.php'), 2);
    expect(transporte.quantidade('tela_nfe_saida/listar_bancos.php'), 1);
    expect(transporte.quantidade('comandas/listar.php'), 1);
    expect(transporte.quantidade('produtos/listar_por_categoria.php'), 1);
  });

  test('evento financeiro durante consulta nao perde invalidacao do preparo',
      () async {
    transporte.liberarPagamentos = Completer<void>();
    sync.iniciar();
    await sync.sincronizar();
    await transporte.pagamentoIniciado.future
        .timeout(const Duration(seconds: 3));
    transporte.versaoPagamentos = 2;
    socket.aoAtualizarDados?.call('bancos');
    transporte.liberarPagamentos!.complete();
    await sync.aguardarPreparacaoOffline();
    expect(transporte.quantidade('tela_nfe_saida/listar_bancos.php'), 1);

    await sync.sincronizar();
    await sync.aguardarPreparacaoOffline();
    expect(transporte.quantidade('tela_nfe_saida/listar_bancos.php'), 2);
    final consulta = transporte.chamadas.lastWhere((options) =>
        CacheConsultas.caminho(options) == 'tela_nfe_saida/listar_bancos.php');
    final salvo =
        await banco.consulta(sync.escopo, CacheConsultas.chave(consulta));
    expect(jsonDecode(salvo!['valor'] as String), [
      {'id': '1', 'nome': 'Banco 2'},
    ]);
  });

  test('somente detalhesCompletos booleano dispensa consulta individual',
      () async {
    transporte.produtos = [
      {'id': 'completo', 'valorVenda': '12.00', 'detalhesCompletos': true},
      {
        'id': 'legado',
        'tamanhosPizza': [
          {'id': 'G'},
        ],
      },
      {'id': 'texto', 'detalhesCompletos': 'true'},
      {'id': 'incompleto', 'detalhesCompletos': false},
    ];
    await sync.sincronizar();
    await sync.aguardarPreparacaoOffline();

    final detalhes = transporte.chamadas
        .where((c) => CacheConsultas.caminho(c) == 'produtos/listar_por_id.php')
        .map((c) => (
              c.uri.queryParameters['id'],
              c.uri.queryParameters['id_tamanhos_pizza'],
            ));
    expect(detalhes, [
      ('legado', '0'),
      ('legado', 'G'),
      ('texto', '0'),
      ('incompleto', '0'),
    ]);
    final catalogo =
        jsonDecode((await banco.ler('catalogo:${sync.escopo}'))!) as Map;
    expect(catalogo['detalhes']['completo:0']['valorVenda'], '12.00');
    expect(catalogo['detalhes']['legado:G']['id'], 'legado');
  });

  test('catalogo de fundo preserva resposta fresca recebida pela tela',
      () async {
    transporte.liberarDetalhe = Completer<void>();
    await sync.sincronizar();
    await transporte.detalheIniciado.future.timeout(const Duration(seconds: 3));
    // A consulta abaixo acontece depois do inicio do retrato de fundo.
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final resposta =
        await api.cliente.get('produtos/listar_por_id.php', queryParameters: {
      'empresa': '32',
      'id_usuario': '1',
      'id': '5',
      'id_tamanhos_pizza': '0',
    });
    expect(resposta.data['valorVenda'], '17.00');
    final chave = CacheConsultas.chave(resposta.requestOptions);
    expect(await banco.consulta(sync.escopo, chave), isNotNull);

    transporte.liberarDetalhe!.complete();
    await sync.aguardarPreparacaoOffline();

    final consulta = await banco.consulta(sync.escopo, chave);
    expect(consulta, isNotNull);
    expect(jsonDecode(consulta!['valor'] as String)['valorVenda'], '17.00');
    final catalogo =
        jsonDecode((await banco.ler('catalogo:${sync.escopo}'))!) as Map;
    expect(catalogo['detalhes']['5:0']['valorVenda'], '10.00');
  });

  test('falha no preparo preserva catalogo anterior e nao bloqueia a fila',
      () async {
    const anterior = '{"produtos":[{"id":"anterior"}],"detalhes":{}}';
    await banco.gravar('catalogo:${sync.escopo}', anterior);
    transporte.falharDetalhe = true;
    await sync.sincronizar();
    await sync.aguardarPreparacaoOffline();
    expect(await banco.ler('catalogo:${sync.escopo}'), anterior);

    await incluirPedidoPendente();
    await sync.sincronizar();
    await sync.aguardarPreparacaoOffline();

    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect(transporte.quantidade('sincronizacao/operacao.php'), 1);
    expect(await banco.ler('catalogo:${sync.escopo}'), anterior);
    expect(sync.online, isTrue);
  });
}
