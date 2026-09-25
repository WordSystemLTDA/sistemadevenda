import 'package:app/src/essencial/utils/numero_pedido_operacional.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('aceita somente numero operacional positivo confirmado', () {
    expect(numeroPedidoOperacionalConfirmado(' 42 '), '42');
    expect(numeroPedidoOperacionalConfirmado(7), '7');
    expect(numeroPedidoOperacionalConfirmado('001'), '001');
  });

  test('recusa identificadores locais e numeros ausentes', () {
    for (final valor in [
      null,
      '',
      '0',
      '-1',
      'Local ABC123',
      'delivery-local:1'
    ]) {
      expect(numeroPedidoOperacionalConfirmado(valor), isNull);
    }
    expect(
        () => exigirNumeroPedidoOperacional('Local ABC123'), throwsStateError);
  });
}
