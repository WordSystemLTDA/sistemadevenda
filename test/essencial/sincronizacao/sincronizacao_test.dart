import 'dart:convert';
import 'dart:io';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
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
  final aplicados = <String>{};
  final tentativas = <Map<String, dynamic>>[];
  const contexto = ContextoCarrinho(
      empresa: '32', tipo: 'comanda', idAtendimento: '104', idRecurso: '4');

  setUp(() async {
    conectado = false;
    perderResposta = false;
    conflito = false;
    aplicados.clear();
    tentativas.clear();
    SharedPreferences.setMockInitialValues({'conexao': jsonEncode({
      'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})});
    pasta = await Directory.systemTemp.createTemp('garcom-teste-');
    banco = await BancoLocal.abrir(factory: databaseFactoryFfi,
        path: '${pasta.path}/pedidos.db');
    BancoLocal.instancia = banco;
    api = DioCliente();
    usuario = UsuarioProvedor()
      ..setUsuario(UsuarioModelo(id: '1', empresa: '32', nome: 'Garcom'));
    socket = SocketOfflineTeste();
    sync = Sincronizador(api, usuario, socket, banco: banco);
    api.cliente.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      final rota = CacheConsultas.caminho(options);
      Map<String, dynamic>? pedido;
      if (options.method == 'POST') {
        pedido = jsonDecode(options.data as String) as Map<String, dynamic>;
        tentativas.add(pedido);
      }
      if (!conectado) {
        handler.reject(DioException(requestOptions: options,
            type: DioExceptionType.connectionError));
        return;
      }
      if (pedido != null) {
        if (conflito && pedido['dados']['id_comanda_pedido'] == '104') {
          handler.reject(DioException(requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response(requestOptions: options, statusCode: 409,
                  data: {'mensagem': 'Atendimento encerrado'})));
          return;
        }
        aplicados.add(pedido['id_operacao'] as String);
        if (perderResposta) {
          perderResposta = false;
          handler.reject(DioException(requestOptions: options,
              type: DioExceptionType.receiveTimeout));
          return;
        }
        handler.resolve(Response(requestOptions: options, statusCode: 200,
            data: {'protocolo': 1, 'sucesso': true,
              'id_operacao': pedido['id_operacao']}));
        return;
      }
      final Object dados = rota == 'sincronizacao/estado.php'
          ? {'protocolo': 1, 'atendimentos': {
              '104': {'id': '104', 'versao': 'versao-original'},
              '106': {'id': '106', 'versao': 'versao-outra'},
            }} : rota == 'config_bigchef/listar.php' ? <String, dynamic>{} : [];
      handler.resolve(Response(requestOptions: options, data: dados, statusCode: 200));
    }));
    await sync.configurar();
    await banco.gravar('estado:${sync.escopo}', jsonEncode({'atendimentos': {
      '104': {'versao': 'versao-original'}, '106': {'versao': 'versao-outra'},
    }}));
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

  Future<void> guardar({ContextoCarrinho alvo = contexto, bool recorrentes = false}) async {
    final item = produto(id: '5', nome: 'Pizza', codigo: '5', computador: 'Cozinha')
      ..quantidade = 2
      ..observacao = 'Sem cebola';
    await ArmazenamentoCarrinhos.instancia.alterar(alvo,
        (itens) => itens.add(item), recorrentes: recorrentes);
    await sync.guardarPedido(contexto: alvo, itens: [item], idMesa: '0',
        idComanda: alvo.idRecurso, idCliente: '0', recorrentes: recorrentes,
        impressoes: [jsonEncode({'idRequisicao': 'impressao-${alvo.idAtendimento}',
          'tipoImpressao': '1', 'idEmpresa': '32', 'produtos': [item.toMap()]})]);
    await sync.enviarPendentes();
  }

  for (final recorrentes in [false, true]) {
    test('salva pedido e limpa somente o carrinho correspondente; recorrentes=$recorrentes', () async {
      await guardar(recorrentes: recorrentes);
      final fila = await banco.operacoes(sync.escopo);
      expect(fila, hasLength(1));
      expect(fila.single['estado'], 'pendente');
      expect(socket.filaImpressao.itens, isEmpty);
      expect(await ArmazenamentoCarrinhos.instancia.listar(contexto,
          recorrentes: recorrentes), isEmpty);
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

  test('resposta perdida repete o mesmo ID, sem registrar produtos duas vezes', () async {
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

  test('conflito preserva os dados e nao impede outro atendimento de sincronizar', () async {
    await guardar();
    await guardar(alvo: const ContextoCarrinho(empresa: '32', tipo: 'comanda',
        idAtendimento: '106', idRecurso: '6'));
    conectado = true;
    conflito = true;
    await sync.tentarNovamente();
    final pendentes = await banco.operacoes(sync.escopo);
    expect(pendentes.single['estado'], 'conflito');
    expect(pendentes.single['atendimento'], '104');
    expect(jsonDecode(pendentes.single['dados'] as String)['produtos'], hasLength(1));
    expect(socket.filaImpressao.itens.single.id, 'impressao-106');
    final envios = tentativas.length;
    await sync.tentarNovamente();
    expect(tentativas.length, envios);
  });

  test('reabrir o banco recupera os pedidos ainda nao enviados', () async {
    await guardar();
    final fila = await banco.operacoes(sync.escopo);
    final outro = await BancoLocal.abrir(factory: databaseFactoryFfi,
        path: '${pasta.path}/pedidos.db');
    expect((await outro.operacoes(sync.escopo)).single['id'], fila.single['id']);
    // A fabrica compartilha o handle do mesmo arquivo dentro do processo.
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

  test('carrinho alterado durante a finalizacao nao e apagado nem enfileirado', () async {
    final item = produto(id: '5', nome: 'Pizza', codigo: '5', computador: 'Cozinha');
    await ArmazenamentoCarrinhos.instancia.alterar(contexto, (itens) => itens.add(item));
    final diferente = produto(id: '8', nome: 'Suco', codigo: '8', computador: 'Cozinha');
    await expectLater(sync.guardarPedido(contexto: contexto, itens: [diferente],
        idMesa: '0', idComanda: '4', idCliente: '0', impressoes: []), throwsStateError);
    expect(await banco.operacoes(sync.escopo), isEmpty);
    expect((await ArmazenamentoCarrinhos.instancia.listar(contexto)).single.id, '5');
  });

  test('ACK de impressao impede recriar fila apos reinicio entre confirmacao e limpeza', () async {
    final mensagem = jsonEncode({'idRequisicao': 'ack-1', 'tipoImpressao': '1'});
    await socket.filaImpressao.registrar([mensagem]);
    await socket.filaImpressao.confirmar('ack-1');
    await socket.filaImpressao.registrar([mensagem]);
    expect(socket.filaImpressao.itens, isEmpty);
  });

  test('catalogo local permite pesquisa e pagina ainda nao consultadas na rede', () async {
    final itens = [
      produto(id: '5', codigo: '5', nome: 'Quatro Queijos', computador: 'Cozinha').toMap(),
      produto(id: '50', codigo: '50', nome: 'Atum', computador: 'Cozinha').toMap(),
    ];
    await banco.gravar('catalogo:${sync.escopo}', jsonEncode({'produtos': itens, 'detalhes': {}}));
    final resposta = await api.cliente.get('produtos/listar.php', queryParameters: {
      'pesquisa': '05', 'codigo_exato': 'Sim', 'empresa': '32',
      'categoria': '0', 'id_usuario': '1', 'id_cliente': '0',
    });
    expect(resposta.data, hasLength(1));
    expect(resposta.data.single['codigo'], '5');
    final todos = await api.cliente.get('produtos/listar_por_categoria.php', queryParameters: {
      'categoria': '0', 'empresa': '32', 'id_usuario': '1', 'pagina': 1,
    });
    expect(todos.data, hasLength(2));
    await Future<void>.delayed(const Duration(milliseconds: 30));
  });
}
