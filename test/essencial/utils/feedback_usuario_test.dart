import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> chamadas;

  setUp(() {
    chamadas = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (methodCall) async {
      chamadas.add(methodCall);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  test('produto adicionado aciona impacto forte', () async {
    FeedbackUsuario.produtoAdicionado();
    await _aguardarMicrotarefas();

    expect(chamadas, hasLength(1));
    expect(chamadas.single.method, 'HapticFeedback.vibrate');
    expect(chamadas.single.arguments, 'HapticFeedbackType.heavyImpact');
  });

  test('pedido finalizado aciona impacto forte', () async {
    FeedbackUsuario.pedidoFinalizado();
    await _aguardarMicrotarefas();

    expect(chamadas, hasLength(1));
    expect(chamadas.single.method, 'HapticFeedback.vibrate');
    expect(chamadas.single.arguments, 'HapticFeedbackType.heavyImpact');
  });

  test('selecao alterada aciona impacto medio', () async {
    FeedbackUsuario.selecaoAlterada();
    await _aguardarMicrotarefas();

    expect(chamadas, hasLength(1));
    expect(chamadas.single.method, 'HapticFeedback.vibrate');
    expect(chamadas.single.arguments, 'HapticFeedbackType.mediumImpact');
  });

  test('falha de haptico nao quebra o fluxo', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async {
      throw PlatformException(code: 'indisponivel');
    });

    FeedbackUsuario.produtoAdicionado();
    await _aguardarMicrotarefas();
  });
}

Future<void> _aguardarMicrotarefas() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
