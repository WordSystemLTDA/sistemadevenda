import 'package:app/src/essencial/widgets/dialogo_atualizacao_disponivel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> abrirDialogo(
    WidgetTester tester, {
    required Future<bool> Function() onAtualizar,
    Future<bool> Function()? onBaixarApk,
    Size tamanho = const Size(393, 852),
    double escalaTexto = 1,
  }) async {
    tester.view.physicalSize = tamanho;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(escalaTexto),
          ),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                onPressed: () => exibirDialogoAtualizacaoDisponivel(
                  context: context,
                  versaoInstalada: '1.0.36',
                  versaoDisponivel: '1.0.37',
                  onAtualizar: onAtualizar,
                  onBaixarApk: onBaixarApk,
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra versoes e orientacoes da atualizacao', (tester) async {
    await abrirDialogo(tester, onAtualizar: () async => true);

    expect(find.text('Uma nova versão está pronta'), findsOneWidget);
    expect(find.text('Instalada'), findsOneWidget);
    expect(find.text('1.0.36'), findsOneWidget);
    expect(find.text('Nova versão'), findsOneWidget);
    expect(find.text('1.0.37'), findsOneWidget);
    expect(
      find.text('Sua conta e seus pedidos permanecem disponíveis.'),
      findsOneWidget,
    );
    expect(find.text('Atualizar agora'), findsOneWidget);
    expect(find.text('Baixar APK'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('oferece download do APK quando configurado', (tester) async {
    var baixouApk = false;
    await abrirDialogo(
      tester,
      onAtualizar: () async => true,
      onBaixarApk: () async {
        baixouApk = true;
        return true;
      },
    );

    await tester.ensureVisible(find.byKey(const ValueKey('baixar-apk')));
    await tester.tap(find.byKey(const ValueKey('baixar-apk')));
    await tester.pump();

    expect(baixouApk, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('informa quando o link nao pode ser aberto', (tester) async {
    await abrirDialogo(tester, onAtualizar: () async => false);

    await tester.ensureVisible(find.byKey(const ValueKey('atualizar-agora')));
    await tester.tap(find.byKey(const ValueKey('atualizar-agora')));
    await tester.pump();

    expect(
      find.textContaining('Não foi possível abrir a atualização'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('continua utilizavel em tela pequena com texto ampliado',
      (tester) async {
    await abrirDialogo(
      tester,
      onAtualizar: () async => true,
      onBaixarApk: () async => true,
      tamanho: const Size(320, 568),
      escalaTexto: 1.35,
    );

    expect(find.text('Uma nova versão está pronta'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('atualizar-agora')));
    expect(find.byKey(const ValueKey('atualizar-agora')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
