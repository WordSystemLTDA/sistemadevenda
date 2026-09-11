import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cliente http tem timeout de resposta configurado', () {
    final dio = DioCliente();
    addTearDown(() => dio.cliente.close());

    expect(dio.cliente.options.connectTimeout, DioCliente.tempoConexao);
    expect(dio.cliente.options.sendTimeout, DioCliente.tempoEnvio);
    expect(dio.cliente.options.receiveTimeout, DioCliente.tempoResposta);
  });
}
