import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ServidorAtualizacoes implements HttpClientAdapter {
  final String contentType;
  RequestOptions? consulta;

  _ServidorAtualizacoes({this.contentType = Headers.jsonContentType});

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    consulta = options;
    return ResponseBody.fromString(
      jsonEncode({
        'dadosConfig': {
          'versaoAppAndroid': '1.0.40',
          'versaoAppIos': '1.0.41',
          'linkAtualizacaoAndroid': 'https://loja.example/android',
          'linkAtualizacaoIos': 'https://loja.example/ios',
          'linkBaixarApk': '',
          'nomeApp': '',
          'anoApp': '',
          'logoApp': '',
        },
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [contentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('consulta atualização online sem usuário mesmo com conexão local',
      () async {
    SharedPreferences.setMockInitialValues({
      'conexao': jsonEncode({
        'tipoConexao': 'local',
        'servidor': '192.168.2.113',
        'porta': '9980',
      }),
    });
    final api = DioCliente(servidor: 'http://cozinha.local/api/');
    addTearDown(() => api.cliente.close());
    final servidor = _ServidorAtualizacoes();
    api.cliente.httpClientAdapter = servidor;
    final usuario = UsuarioProvedor();
    final config = ConfigProvider();

    final atualizacao =
        await ServicoConfig(api, usuario, config).consultarAtualizacao();

    expect(usuario.usuario, isNull);
    expect(config.configs, isNull);
    expect(servidor.consulta!.uri.scheme, 'https');
    expect(servidor.consulta!.uri.host, 'bigchef.com.br');
    expect(servidor.consulta!.uri.path, endsWith('/config/listar.php'));
    expect(servidor.consulta!.queryParameters, isNot(contains('empresa')));
    expect(servidor.consulta!.extra['semCache'], isTrue);
    expect(atualizacao.linkAtualizacaoIos, 'https://loja.example/ios');
    expect(atualizacao.linkAtualizacaoAndroid, 'https://loja.example/android');
  });

  test('primeiro acesso sem configuração aceita resposta JSON em texto',
      () async {
    final api = DioCliente();
    addTearDown(() => api.cliente.close());
    api.cliente.httpClientAdapter =
        _ServidorAtualizacoes(contentType: 'text/plain');
    final servico = ServicoConfig(api, UsuarioProvedor(), ConfigProvider());

    final atualizacao = await servico.consultarAtualizacao();

    expect(atualizacao.versaoAppAndroid, '1.0.40');
    expect(atualizacao.versaoAppIos, '1.0.41');
  });
}
