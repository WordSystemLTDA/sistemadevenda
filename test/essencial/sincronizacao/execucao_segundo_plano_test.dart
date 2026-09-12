import 'package:app/src/essencial/sincronizacao/execucao_segundo_plano.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final chamadas = <MethodCall>[];
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    chamadas.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ExecucaoSegundoPlano.canal, (call) async {
      chamadas.add(call);
      return call.method == 'iniciarEnvio' ? 42 : null;
    });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ExecucaoSegundoPlano.canal, null);
  });

  test('encerra a extensao do iOS apos concluir envio', () async {
    expect(await ExecucaoSegundoPlano.executar(() async => true), isTrue);
    expect(chamadas.map((c) => c.method), ['iniciarEnvio', 'concluirEnvio']);
    expect(chamadas.last.arguments, 42);
  });

  test('encerra a extensao do iOS mesmo se o envio falhar', () async {
    await expectLater(
        ExecucaoSegundoPlano.executar(() async => throw StateError('rede')),
        throwsStateError);
    expect(chamadas.last.method, 'concluirEnvio');
  });

  test('tempo adicional negado nao impede a execucao', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            ExecucaoSegundoPlano.canal, (_) async => null);
    expect(await ExecucaoSegundoPlano.executar(() async => true), isTrue);
  });
}
