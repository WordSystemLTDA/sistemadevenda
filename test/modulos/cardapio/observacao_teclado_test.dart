import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_editar_observacao.dart';
import 'package:app/src/modulos/cardapio/provedores/observacoes_rapidas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'finalizacao_carrinhos_test.dart' show ModuloFinalizacaoTeste;

void main() {
  setUpAll(carregarFontesDeTeste);
  for (final (largura, altura, escala) in [
    (320.0, 568.0, 1.0),
    (393.0, 852.0, 1.0),
    (320.0, 568.0, 1.5),
    (800.0, 900.0, 1.3),
  ]) {
    testWidgets(
        'salva sugestao do aparelho com teclado aberto em $largura/$escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        ObservacoesRapidas.chave: ['Cortar em 8']
      });
      final modulo = ModuloFinalizacaoTeste();
      app.usuarioProvedor = modulo.usuario;
      Modular.init(modulo);
      tester.view.physicalSize = Size(largura, altura);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetViewInsets();
        modulo.servidor.dispose();
        modulo.carrinho.dispose();
        modulo.recorrentes.dispose();
        modulo.cardapio.dispose();
        modulo.usuario.dispose();
        modulo.api.cliente.close();
        Modular.destroy();
      });
      await modulo.selecionar('4');
      await modulo.adicionar('Pizza', 'pizza', pizza: true);
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                      body: TextButton(
                    onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const ModalEditarObservacao(
                            idProduto: 'pizza', observacao: '', index: 0)),
                    child: const Text('Observação'),
                  ))),
        ),
      ));
      await tester.tap(find.text('Observação'));
      await tester.pumpAndSettle();
      await tester
          .ensureVisible(find.widgetWithText(ActionChip, 'Cortar em 8'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ActionChip, 'Cortar em 8'));
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Cortar em 8');
      await capturarTela(tester, 'observacao_modal_${largura.toInt()}_$escala');
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'Cortar em 8, bem quente');
      const teclado = 260.0;
      tester.view.viewInsets = const FakeViewPadding(bottom: teclado);
      await tester.pumpAndSettle();
      final salvar = find.widgetWithText(FilledButton, 'Salvar observação');
      expect(
          tester.getRect(salvar).bottom, lessThanOrEqualTo(altura - teclado));
      expect(salvar.hitTestable(), findsOneWidget);
      await capturarTela(
          tester, 'observacao_modal_teclado_${largura.toInt()}_$escala');
      await tester.tap(salvar);
      await tester.pumpAndSettle();
      expect(find.byType(ModalEditarObservacao), findsNothing);
      expect(
          modulo.carrinho.itensCarrinho.listaComandosPedidos.single.observacao,
          'Cortar em 8, bem quente');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
