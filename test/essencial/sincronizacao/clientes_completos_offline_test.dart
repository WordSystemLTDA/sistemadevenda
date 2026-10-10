import 'dart:convert';
import 'dart:typed_data';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/essencial/sincronizacao/politica_offline_online.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _SemInternet implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async => throw DioException(requestOptions: options, type: DioExceptionType.connectionError);
  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  late Dio dio;
  late CacheConsultas cache;
  setUp(() async {
    banco = await BancoLocal.abrir(factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    dio = Dio(BaseOptions(baseUrl: 'https://teste.invalid/api41/'))..httpClientAdapter = _SemInternet();
    cache = CacheConsultas(dio, banco)..escopo = 'empresa81-usuario1'..empresa = '81'..servidor = dio.options.baseUrl;
    dio.interceptors.add(cache);
    await banco.gravar('clientes-completos:empresa81-usuario1', jsonEncode(List.generate(40,(i) => {'id':'${i+1}','nome':'Cliente ${i+1}','razaoSocial':'Cliente ${i+1}','celular': i==39 ? '(44) 99921-3336' : ''})));
  });
  tearDown(() async { dio.close(force: true); await banco.db.close(); });

  test('politica limita nova preparacao a instalador 2 e conexao online', () {
    expect(PoliticaOfflineOnline.permite('online',instalador:'2',ambiente:'online'),true);
    expect(PoliticaOfflineOnline.permite('online',instalador:'1',ambiente:'online'),false);
    expect(PoliticaOfflineOnline.permite('localhost',instalador:'2',ambiente:'online'),false);
    expect(PoliticaOfflineOnline.permite('online',instalador:'2',ambiente:'localhost'),false);
  });
  test('cliente fora dos primeiros 15 aparece sem mascara e sem internet', () async {
    final resposta = await dio.get('comandas/listar_clientes.php',queryParameters:{'empresa':'81','pesquisa':'44999213336'});
    expect((resposta.data as List).single['id'],'40');
    expect(resposta.extra['cacheLocal'],true);
  });
  test('paginacao offline completa prevalece sobre busca curta salva', () async {
    final opcoes = RequestOptions(path:'comandas/listar_clientes.php',baseUrl:dio.options.baseUrl,queryParameters:{'empresa':'81','pesquisa':'','paginado':'1'});
    await banco.guardarConsulta(cache.escopo,CacheConsultas.chave(opcoes),{'dados':[{'id':'1'}],'tem_mais':false});
    final primeira = await dio.get(opcoes.path,queryParameters:opcoes.queryParameters);
    expect(primeira.data['dados'],hasLength(15));
    expect(primeira.data['dados'].first['id'],'40');
    expect(primeira.data['tem_mais'],true);
    final segunda = await dio.get(opcoes.path,queryParameters:{...opcoes.queryParameters,'antes_id':primeira.data['proximo_id']});
    expect(segunda.data['dados'].first['id'],'25');
    expect(segunda.data['dados'],hasLength(15));
  });
  test('troca de empresa nao expoe catalogo da sessao anterior', () async {
    cache..escopo = 'empresa82-usuario1'..empresa = '82';
    await expectLater(dio.get('comandas/listar_clientes.php',queryParameters:{'empresa':'82','pesquisa':'Cliente 40'}),throwsA(isA<DioException>()));
  });
}
