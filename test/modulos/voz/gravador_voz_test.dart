import 'package:app/src/modulos/voz/gravador_voz.dart';
import 'package:app/src/modulos/voz/falha_pedido_voz.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const canal = MethodChannel('com.llfbandit.record/messages');
  final chamadas = <String>[];
  setUp(chamadas.clear);
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
  });

  test('abrir e fechar janela nao inicializa plugin nativo', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(canal,
        (call) async {
      chamadas.add(call.method);
      throw MissingPluginException();
    });
    final gravador = GravadorVoz();
    await Future<void>.delayed(Duration.zero);
    await gravador.cancelar();
    await gravador.dispose();
    expect(chamadas, isEmpty);
  });

  test('erro de criacao nativa fica no Future de iniciar', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(canal,
        (call) async {
      chamadas.add(call.method);
      throw MissingPluginException();
    });
    final gravador = GravadorVoz();
    await expectLater(
        gravador.iniciar(), throwsA(isA<MissingPluginException>()));
    expect(chamadas, ['create']);
    await expectLater(
        gravador.dispose(), throwsA(isA<MissingPluginException>()));
  });

  test('permissao negada nao inicia audio nem cria arquivo', () async {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(canal,
        (call) async {
      chamadas.add(call.method);
      return call.method == 'hasPermission' ? false : null;
    });
    final gravador = GravadorVoz();
    await expectLater(gravador.iniciar(), throwsA(isA<FalhaPedidoVoz>()));
    await gravador.dispose();
    expect(chamadas, ['create', 'hasPermission', 'dispose']);
  });
}
