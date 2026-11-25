import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/sincronizacao/cache_consultas.dart';
import 'package:app/src/modulos/delivery/servicos/preparacao_delivery_offline.dart';

void main() {
  for (final flag in ['Sim', 'Não', 'desconhecido']) {
    test(
        'preparacao consulta recorrentes somente quando a configuracao permite: $flag',
        () async {
      final pedidos = <String>[];
      final http = Dio(BaseOptions(baseUrl: 'http://fixture.local/'))
        ..httpClientAdapter = _Adaptador((o) {
          pedidos.add(o.path);
          if (o.path == 'config_bigchef/listar.php') {
            return {'clientecompedidosdecorrentes': flag};
          }
          return <Object>[];
        });
      addTearDown(http.close);
      await PreparacaoDeliveryOffline(_Cliente(http)).preparar(
          escopo: 'teste',
          servidor: 'http://fixture.local/',
          empresa: '86',
          usuario: '9');
      expect(pedidos.contains('recorrentes/listar.php'), flag == 'Sim');
      expect(
          pedidos,
          containsAll([
            'config_bigchef/listar.php',
            'permissoes_bigchef/listar_permissoes_bigchef.php',
            'comandas/listar_clientes.php'
          ]));
    });
  }
}

class _Cliente extends Fake implements DioCliente {
  _Cliente(this.cliente);
  @override
  final Dio cliente;
  @override
  CacheConsultas get cache => _Cache();
}

class _Cache extends Fake implements CacheConsultas {
  @override
  String get escopo => 'teste';
  @override
  String get servidor => 'http://fixture.local/';
  @override
  bool get servidorDisponivel => true;
}

class _Adaptador implements HttpClientAdapter {
  _Adaptador(this.responder);
  final Object Function(RequestOptions) responder;
  @override
  Future<ResponseBody> fetch(RequestOptions options,
          Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString(jsonEncode(responder(options)), 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });
  @override
  void close({bool force = false}) {}
}
