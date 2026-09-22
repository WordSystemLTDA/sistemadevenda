import 'dart:convert';
import 'dart:typed_data';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

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

  for (final versaoApi in ['api1', 'api37']) {
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
