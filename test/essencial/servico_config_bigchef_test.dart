import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _BancoConfig extends BancoLocal {
  _BancoConfig(super.db);
  int gravacoes = 0;

  @override
  Future<void> guardarConsulta(String escopo, String chave, Object? valor) {
    gravacoes++;
    return super.guardarConsulta(escopo, chave, valor);
  }
}

class _HttpConfig implements HttpClientAdapter {
  int chamadas = 0;
  bool offline = false;
  final iniciou = Completer<void>();
  Completer<void>? liberar;

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas++;
    if (!iniciou.isCompleted) iniciou.complete();
    await liberar?.future;
    if (offline) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(
        jsonEncode({'clientecompedidosdecorrentes': 'Sim'}), 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
  }

  @override
  void close({bool force = false}) {}
}

class _AdaptadorConfigAntiga implements HttpClientAdapter {
  final chamadas = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    chamadas.add(options);
    final desktop = options.uri.path.contains('/api_desktop/1.0.01/');
    return ResponseBody.fromString(
      jsonEncode(desktop
          ? {
              'clientecompedidosdecorrentes': 'Sim',
              'valorembalagemseparada': '5.00',
              'aumentarfontenumeropedidoentregador': 'Sim',
              'aumentarfontetotaisentregador': 'Não',
              'aumentarfontepagamentoentregador': 'Sim',
              'imprimircodigoprodutopreparo': 'Sim',
            }
          : {'valordaentrega': '4.00'}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  group('inicializacao sem internet', () {
    late Directory temporario;
    late _BancoConfig banco;
    late DioCliente api;
    late UsuarioProvedor usuario;
    late _HttpConfig http;
    late String servidor;
    late String caminhoBanco;

    setUp(() async {
      temporario = await Directory.systemTemp.createTemp('inicio-offline-');
      caminhoBanco = '${temporario.path}/config.db';
      servidor = 'http://cozinha-${temporario.path.split('/').last}/api41/';
      banco = _BancoConfig((await BancoLocal.abrir(
              factory: databaseFactoryFfi, path: caminhoBanco))
          .db);
      BancoLocal.instancia = banco;
      api = DioCliente(servidor: servidor);
      http = _HttpConfig();
      api.cliente.httpClientAdapter = http;
      usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(id: '275', empresa: '32'));
    });

    tearDown(() async {
      BancoLocal.instancia = null;
      api.cliente.close(force: true);
      usuario.dispose();
      await banco.db.close();
      await temporario.delete(recursive: true);
    });

    String chaveConsulta() => CacheConsultas.chave(RequestOptions(
        path: 'config_bigchef/listar.php',
        baseUrl: servidor,
        queryParameters: {'empresa': '32'}));

    Future<void> salvarConfig() => banco.guardarConsulta(
          BancoLocal.escopo(servidor, '32', '275'),
          chaveConsulta(),
          {'clientecompedidosdecorrentes': 'Sim', 'valordaentrega': '4.00'},
        );

    test('reabrir banco recupera configuracao antes da primeira consulta HTTP',
        () async {
      await salvarConfig();
      await banco.db.close();
      banco = _BancoConfig((await BancoLocal.abrir(
              factory: databaseFactoryFfi, path: caminhoBanco))
          .db);
      BancoLocal.instancia = banco;
      api.cliente.close(force: true);
      api = DioCliente(servidor: servidor);
      api.cliente.httpClientAdapter = http;
      http.offline = true;

      final salva = await ServicoConfigBigchef(api, usuario).listarSalva();

      expect(salva?.recorrentesHabilitados, isTrue);
      expect(salva?.valordaentrega, '4.00');
      expect(usuario.configbigchef, same(salva));
      expect(http.chamadas, 0);
    });

    test('consulta forcada salva configuracao para o proximo inicio', () async {
      await ServicoConfigBigchef(api, usuario).listar(forcarAtualizacao: true);
      final registro = await banco.consulta(
          BancoLocal.escopo(servidor, '32', '275'), chaveConsulta());
      expect(jsonDecode(registro!['valor'] as String),
          {'clientecompedidosdecorrentes': 'Sim'});
    });

    test('ler configuracao em cache nao a marca como sincronizada novamente',
        () async {
      await salvarConfig();
      api.cache!
        ..escopo = BancoLocal.escopo(servidor, '32', '275')
        ..servidor = servidor
        ..empresa = '32';
      final gravacoes = banco.gravacoes;

      final config = await ServicoConfigBigchef(api, usuario).listar();

      expect(config?.recorrentesHabilitados, isTrue);
      expect(banco.gravacoes, gravacoes);
      expect(http.chamadas, 0);
    });

    test('falha externa recupera copia SQLite sem cache em memoria', () async {
      await salvarConfig();
      http.offline = true;

      final salva = await ServicoConfigBigchef(api, usuario)
          .listar(forcarAtualizacao: true);

      expect(salva?.recorrentesHabilitados, isTrue);
      expect(http.chamadas, 1);
    });

    test('configuracao local nao atravessa usuario empresa ou API', () async {
      await salvarConfig();
      final servico = ServicoConfigBigchef(api, usuario);
      expect(await servico.listarSalva(), isNotNull);

      usuario.setUsuario(UsuarioModelo(id: '276', empresa: '32'));
      expect(await servico.listarSalva(), isNull);
      usuario.setUsuario(UsuarioModelo(id: '275', empresa: '33'));
      expect(await servico.listarSalva(), isNull);
      usuario.setUsuario(UsuarioModelo(id: '275', empresa: '32'));
      final outraApi = DioCliente(servidor: 'http://outra-cozinha/api41/');
      addTearDown(() => outraApi.cliente.close(force: true));
      expect(
          await ServicoConfigBigchef(outraApi, usuario).listarSalva(), isNull);
      expect(http.chamadas, 0);
    });

    test('resposta atrasada nao aplica configuracao a outra sessao', () async {
      final liberar = Completer<void>();
      http.liberar = liberar;
      final consulta =
          ServicoConfigBigchef(api, usuario).listar(forcarAtualizacao: true);
      await http.iniciou.future;
      usuario.setUsuario(UsuarioModelo(id: '276', empresa: '33'));
      liberar.complete();
      expect(await consulta, isNull);
      expect(usuario.configbigchef, isNull);
    });

    test('resposta atrasada nao aplica configuracao apos trocar a API',
        () async {
      SharedPreferences.setMockInitialValues({
        'conexao': jsonEncode({
          'tipoConexao': 'local',
          'servidor': 'cozinha-inicial',
          'porta': '9980',
        }),
      });
      api.cliente.close(force: true);
      api = DioCliente();
      api.cliente.httpClientAdapter = http;
      final liberar = Completer<void>();
      http.liberar = liberar;
      final consulta =
          ServicoConfigBigchef(api, usuario).listar(forcarAtualizacao: true);
      await http.iniciou.future;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'conexao',
          jsonEncode({
            'tipoConexao': 'online',
            'servidor': 'cozinha-inicial',
            'porta': '9980',
          }));
      liberar.complete();
      expect(await consulta, isNull);
      expect(usuario.configbigchef, isNull);
    });
  });

  for (final versaoApi in ['api1', 'api6', 'api37', 'api38', 'api39']) {
    test(
        'completa recorrentes e tarifa pelo desktop quando $versaoApi local e antiga',
        () async {
      final api = DioCliente(
        servidor:
            'http://cozinha/sistema/apis_restaurantes/api_restaurantes_venda/$versaoApi/',
      );
      addTearDown(() => api.cliente.close(force: true));
      final adaptador = _AdaptadorConfigAntiga();
      api.cliente.httpClientAdapter = adaptador;
      final usuario = UsuarioProvedor()
        ..setUsuario(UsuarioModelo(id: '275', empresa: '32'));
      addTearDown(usuario.dispose);

      final config = await ServicoConfigBigchef(api, usuario)
          .listar(forcarAtualizacao: true);

      expect(config?.valorembalagemseparada, '5.00');
      expect(config?.recorrentesHabilitados, isTrue);
      expect(config?.aumentarfontenumeropedidoentregador, 'Sim');
      expect(config?.aumentarfontetotaisentregador, 'Não');
      expect(config?.aumentarfontepagamentoentregador, 'Sim');
      expect(config?.imprimeCodigoSaboresPizza, isTrue);
      expect(usuario.configbigchef?.aumentarfontepagamentoentregador, 'Sim');
      expect(adaptador.chamadas.map((e) => e.uri.path), [
        '/sistema/apis_restaurantes/api_restaurantes_venda/$versaoApi/config_bigchef/listar.php',
        '/sistema/apis_restaurantes/api_desktop/1.0.01/config_bigchef/listar.php',
      ]);
      expect(
        adaptador.chamadas.map((e) => e.uri.queryParameters['empresa']),
        everyElement('32'),
      );
    });
  }
}
