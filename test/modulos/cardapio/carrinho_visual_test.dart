import 'package:app/src/app_widget.dart' as app;
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/conferencia_produto_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';
import 'finalizacao_carrinhos_test.dart' show ModuloFinalizacaoTeste;

void main() {
  setUpAll(carregarFontesDeTeste);
  for (final (largura, escala) in [(393.0, 1.0), (320.0, 2.0), (800.0, 1.0)]) {
    testWidgets(
        'pizza expandida e conferida sem cobrir total em $largura/$escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final m = ModuloFinalizacaoTeste();
      Modular.init(m);
      app.usuarioProvedor = m.usuario;
      await m.selecionar('4');
      await m.adicionar('Pizza', '1010');
      final item = m.carrinho.itensCarrinho.listaComandosPedidos.single
        ..valorVenda = '82'
        ..observacao = 'Bem assada'
        ..opcoesPacotesListaFinal = [
          ModeloOpcoesPacotes(
              id: 9,
              titulo: 'Tamanho Pizza',
              obrigatorio: false,
              dados: [
                ModeloDadosOpcoesPacotes(id: 'G', nome: 'G', valor: '57'),
              ]),
          ModeloOpcoesPacotes(
              id: 10,
              titulo: 'Sabores Pizza (2)',
              obrigatorio: false,
              dados: [
                ModeloDadosOpcoesPacotes(
                    id: '1',
                    nome: 'Mussarela',
                    valor: '28.50',
                    quantimaximaselecao: '1/2'),
                ModeloDadosOpcoesPacotes(
                    id: '2',
                    nome: 'Catupiry Especial',
                    valor: '28.50',
                    quantimaximaselecao: '1/2'),
              ]),
          ModeloOpcoesPacotes(
              id: 6,
              titulo: 'Bordas (2)',
              obrigatorio: false,
              dados: [
                ModeloDadosOpcoesPacotes(
                    id: '3',
                    nome: 'Cheddar',
                    valor: '6',
                    valorOriginal: '12',
                    quantimaximaselecao: '1/2'),
                ModeloDadosOpcoesPacotes(
                    id: '4',
                    nome: 'Catupiry',
                    valor: '6',
                    valorOriginal: '12',
                    quantimaximaselecao: '1/2'),
              ]),
          ModeloOpcoesPacotes(
              id: 7,
              titulo: 'Adicionais',
              obrigatorio: false,
              dados: [
                ModeloDadosOpcoesPacotes(
                    id: '5', nome: 'Mussarela', valor: '10', quantidade: 1),
                ModeloDadosOpcoesPacotes(
                    id: '6', nome: 'Milho', valor: '3', quantidade: 1),
              ]),
        ];
      await m.carrinho.editar(item, 0);
      tester.view.physicalSize = Size(largura, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        m.servidor.dispose();
        Modular.destroy();
      });
      await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple)),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: const PaginaCarrinho(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'etapa3_carrinho_${largura.toInt()}');
      await tester.ensureVisible(find.byTooltip('Mostrar detalhes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Mostrar detalhes'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Ocultar detalhes'), findsOneWidget);
      await capturarTela(
          tester, 'etapa3_carrinho_expandido_${largura.toInt()}');
      final total = find.byKey(const ValueKey('total_opcoes_carrinho'));
      await tester.ensureVisible(total);
      await tester.pumpAndSettle();
      final scaffold = tester.widget<Scaffold>(find.descendant(
          of: find.byType(PaginaCarrinho), matching: find.byType(Scaffold)));
      expect(scaffold.floatingActionButton, isNull);
      expect(scaffold.bottomNavigationBar, isNotNull);
      final botao = find.text('Finalizar');
      for (var i = 0;
          i < 30 && tester.getRect(total).bottom >= tester.getRect(botao).top;
          i++) {
        await tester.drag(find.byType(ListView).first, const Offset(0, -300));
        await tester.pumpAndSettle();
      }
      expect(tester.getRect(total).bottom, lessThan(tester.getRect(botao).top));
      await tester
          .ensureVisible(find.widgetWithText(OutlinedButton, 'Conferir'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Conferir'));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<CardConferenciaCarrinho>(
                  find.byType(CardConferenciaCarrinho))
              .conferido,
          isTrue);
      expect(find.text('Conferido'), findsOneWidget);
      await tester.drag(find.byType(ListView).first, const Offset(0, 2000));
      await tester.pumpAndSettle();
      await capturarTela(
          tester, 'etapa3_carrinho_conferido_${largura.toInt()}');
      expect(m.carrinho.itensCarrinho.precoTotal, 82);
      expect(find.byType(CardCarrinho), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(m.api.pedidos, isEmpty);
      expect(m.servidor.impressos, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
