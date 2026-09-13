import 'dart:typed_data';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdaptadorApiTeste implements HttpClientAdapter {
  final int status;
  final chamadas = <RequestOptions>[];
  AdaptadorApiTeste(this.status);
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    chamadas.add(options);
    return ResponseBody.fromString('{}', status, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType]
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('servidor fixo preserva contexto da requisicao', () async {
    final api = DioCliente(servidor: 'https://servidor-a/api/');
    addTearDown(() => api.cliente.close());
    final adaptador = AdaptadorApiTeste(200);
    api.cliente.httpClientAdapter = adaptador;
    await api.cliente.get('produtos');
    await api.cliente.get('produtos',
        options: Options(extra: {'servidorFixo': 'https://servidor-b/api/'}));
    expect(adaptador.chamadas.map((r) => r.uri.host),
        ['servidor-a', 'servidor-b']);
  });
  test('401 nao repete a mesma autenticacao em loop', () async {
    final api = DioCliente(servidor: 'https://servidor/api/');
    addTearDown(() => api.cliente.close());
    final adaptador = AdaptadorApiTeste(401);
    api.cliente.httpClientAdapter = adaptador;
    await expectLater(api.cliente.get('sessao'), throwsA(isA<DioException>()));
    expect(adaptador.chamadas, hasLength(1));
  });
  test('configuracao invalida retorna erro em vez de deixar Future pendente',
      () async {
    SharedPreferences.setMockInitialValues({'conexao': '{'});
    final api = DioCliente();
    addTearDown(() => api.cliente.close());
    await expectLater(
        api.cliente.get('produtos').timeout(const Duration(seconds: 2)),
        throwsA(isA<DioException>()));
  });
  test('cliente http tem timeout de resposta configurado', () {
    final dio = DioCliente();
    addTearDown(() => dio.cliente.close());

    expect(dio.cliente.options.connectTimeout, DioCliente.tempoConexao);
    expect(dio.cliente.options.sendTimeout, DioCliente.tempoEnvio);
    expect(dio.cliente.options.receiveTimeout, DioCliente.tempoResposta);
  });
}
