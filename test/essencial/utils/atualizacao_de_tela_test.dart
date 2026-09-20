import 'package:app/src/essencial/api/socket/atualizacao_de_tela.dart';
import 'package:app/src/essencial/api/socket/modelos/modelo_retorno_socket.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ignora atualizacoes quando os provedores nao estao registrados', () {
    for (final tipo in ['Mesa', 'Comanda', 'Balcão', 'Delivery']) {
      expect(
        () => AtualizacaoDeTela().call(ModeloRetornoSocket(tipo: tipo)),
        returnsNormally,
      );
    }
  });
}
