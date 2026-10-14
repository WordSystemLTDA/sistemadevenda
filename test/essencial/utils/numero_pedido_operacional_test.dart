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

  test('impressao aceita numero ausente e prioriza a sequencia confirmada', () {
    for (final numero in [null, '', '0', '-1', 'Local ABC123']) {
      expect(numeroPedidoParaImpressao(numero), '');
    }
    expect(numeroPedidoParaImpressao('88', alternativo: '14'), '88');
    expect(numeroPedidoParaImpressao('0', alternativo: '14'), '14');
  });
}
