import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  late DioCliente api;
  late UsuarioProvedor usuario;
  late ServicoAutenticacao servico;
  var conectado = true;
  var autorizado = true;
  var segurarResposta = false;
  late Completer<RequestInterceptorHandler> respostaPendente;
  RequestOptions? pedidoPendente;
  final conta = UsuarioModelo(
      id: '1', empresa: '32', email: 'teste', senha: 'senha-teste');

  setUp(() async {
    conectado = true;
    autorizado = true;
    segurarResposta = false;
    respostaPendente = Completer<RequestInterceptorHandler>();
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode(
          {'tipoConexao': 'local', 'servidor': 'cozinha', 'porta': '9980'})
    });
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    BancoLocal.instancia = banco;
    api = DioCliente();
    usuario = UsuarioProvedor();
    servico = ServicoAutenticacao(api, usuario);
    api.cliente.interceptors.add(InterceptorsWrapper(onRequest: (op, handler) {
      if (segurarResposta) {
        pedidoPendente = op;
        respostaPendente.complete(handler);
        return;
      }
      if (!conectado || !autorizado) {
        handler.reject(DioException(
            requestOptions: op,
            type: conectado
                ? DioExceptionType.badResponse
                : DioExceptionType.connectionError,
            response: conectado
                ? Response(requestOptions: op, statusCode: 403)
                : null));
      } else {
        handler.resolve(Response(
            requestOptions: op,
            statusCode: 200,
            data: {'sucesso': true, 'resultado': conta.toMap()}));
      }
    }));
    expect(await servico.entrar('teste', 'senha-teste'), isTrue);
    usuario.setUsuario(null);
  });

  tearDown(() async {
    api.cliente.close(force: true);
    usuario.dispose();
    BancoLocal.instancia = null;
    await banco.db.close();
  });

  test('sessao previamente validada pode ser retomada sem rede', () async {
    conectado = false;
    expect(
        await servico.entrar('teste', 'senha-teste', permitirSessaoSalva: true),
        isTrue);
    expect(usuario.usuario?.empresa, '32');
  });

  test('entrada manual sem rede nao autentica credenciais novas pelo cache',
      () async {
    conectado = false;
    expect(await servico.entrar('teste', 'senha-errada'), isFalse);
    expect(usuario.usuario, isNull);
  });

  test('403 revoga retomada offline da sessao', () async {
    autorizado = false;
    expect(
        await servico.entrar('teste', 'senha-teste', permitirSessaoSalva: true),
        isFalse);
    conectado = false;
    expect(
        await servico.entrar('teste', 'senha-teste', permitirSessaoSalva: true),
        isFalse);
  });

  test('trocar servidor nao reutiliza autorizacao do anterior', () async {
    conectado = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'conexao',
        jsonEncode({
          'tipoConexao': 'local',
          'servidor': 'outro-servidor',
          'porta': '9980'
        }));
    expect(
        await servico.entrar('teste', 'senha-teste', permitirSessaoSalva: true),
        isFalse);
  });

  test('servidor sem resposta retoma sessao offline e cancela pedido HTTP',
      () async {
    segurarResposta = true;
    final entrada = servico.entrar('teste', 'senha-teste',
        permitirSessaoSalva: true,
        tempoLimite: const Duration(milliseconds: 50));
    final resposta = await respostaPendente.future;
    expect(await entrada.timeout(const Duration(seconds: 2)), isTrue);
    expect(pedidoPendente!.cancelToken!.isCancelled, isTrue);
    expect(usuario.usuario?.id, '1');

    usuario.setUsuario(null);
    resposta.resolve(Response(
        requestOptions: pedidoPendente!,
        statusCode: 200,
        data: {'sucesso': true, 'resultado': conta.toMap()}));
    await Future<void>.delayed(Duration.zero);
    expect(usuario.usuario, isNull,
        reason: 'Resposta atrasada nao deve autenticar novamente.');
  });

  test('servidor sem resposta nao permite entrada sem sessao autorizada',
      () async {
    await banco.db.delete('documentos');
    segurarResposta = true;
    final entrada = servico.entrar('teste', 'senha-teste',
        permitirSessaoSalva: true,
        tempoLimite: const Duration(milliseconds: 50));
    final resposta = await respostaPendente.future;
    expect(await entrada.timeout(const Duration(seconds: 2)), isFalse);
    expect(usuario.usuario, isNull);
    resposta.reject(pedidoPendente!.cancelToken!.cancelError!);
  });

  test('cancelar login para configurar conexao nao restaura sessao offline',
      () async {
    segurarResposta = true;
    final cancelamento = CancelToken();
    final entrada = servico.entrar('teste', 'senha-teste',
        permitirSessaoSalva: true,
        cancelToken: cancelamento,
        tempoLimite: const Duration(milliseconds: 50));
    final resposta = await respostaPendente.future;
    cancelamento.cancel();
    expect(await entrada.timeout(const Duration(seconds: 2)), isFalse);
    expect(usuario.usuario, isNull);
    resposta.reject(pedidoPendente!.cancelToken!.cancelError!);
  });
}
