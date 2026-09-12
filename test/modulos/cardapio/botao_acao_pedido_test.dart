import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../suporte/captura_tela.dart';

void main() {
  setUpAll(carregarFontesDeTeste);

  for (final (largura, escala) in [(393.0, 1.0), (320.0, 2.0), (800.0, 1.0)]) {
    for (final rotulo in ['Adicionar ao (2)', 'Avancar (2)']) {
      testWidgets('carregamento preserva o rodape: $rotulo $largura/$escala',
          (tester) async {
        tester.view.physicalSize = Size(largura, 852);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final carregando = ValueNotifier(false);
        addTearDown(carregando.dispose);
        var toques = 0;
        await tester.pumpWidget(RepaintBoundary(
          key: const ValueKey('captura'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(platform: TargetPlatform.iOS, fontFamily: 'Roboto'),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(escala),
                  padding: const EdgeInsets.only(top: 54, bottom: 34)),
              child: child!,
            ),
            home: Scaffold(
              appBar: AppBar(title: const Text('Pizza de Queijos')),
              body: const Center(child: Text('Adicionais selecionados')),
              bottomNavigationBar: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: ValueListenableBuilder(
                    valueListenable: carregando,
                    builder: (context, salvando, _) => BotaoAcaoPedido(
                      rotulo: rotulo,
                      iconeRotulo: Icons.shopping_cart_outlined,
                      quantidade: 1,
                      total: 'R\$ 82,00',
                      carregando: salvando,
                      onPressed: () {
                        toques++;
                        carregando.value = true;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
        final botao = find.byType(BotaoAcaoPedido);
        final antes = tester.getRect(botao);
        final conteudoAntes =
            tester.getRect(find.text('Adicionais selecionados'));
        expect(antes.height, lessThan(852 / 2));

        await tester.tap(botao);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(toques, 1);
        expect(tester.getRect(botao), antes,
            reason: 'Salvar nao pode transformar o botao em uma tela inteira.');
        expect(tester.getRect(find.text('Adicionais selecionados')),
            conteudoAntes);
        final progresso = find.byType(CircularProgressIndicator);
        expect(progresso, findsOneWidget);
        expect(tester.getSize(progresso), const Size(24, 24));
        expect(antes.contains(tester.getCenter(progresso)), isTrue);
        expect(tester.widget<Visibility>(find.byType(Visibility)).visible,
            isFalse);
        await tester.tap(botao);
        await tester.pump(const Duration(milliseconds: 300));
        expect(toques, 1);
        expect(tester.getRect(botao), antes);
        await capturarTela(tester, 'botao_salvando_${largura}_$escala');

        carregando.value = false;
        await tester.pump();
        expect(tester.getRect(botao), antes);
        expect(progresso, findsNothing);
        expect(find.text(rotulo), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
