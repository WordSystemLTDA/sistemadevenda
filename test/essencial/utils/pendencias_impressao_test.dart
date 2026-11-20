import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/widgets/atalhos_pendencias_impressao.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../suporte/captura_tela.dart';

void main() {
  setUpAll(carregarFontesDeTeste);
  String mensagem(String id) => jsonEncode({
        'idRequisicao': id,
        'tipoImpressao': '1',
        'tipo': 'Comanda',
        'comanda': 'Comanda: 3',
        'numeroPedido': '10679',
        'nomedopc': 'Cozinha',
        'produtos': [
          {'nome': 'Pizza de queijos especiais', 'quantidade': 1}
        ],
      });

  for (final escala in [1.0, 2.0]) {
    testWidgets(
        'pendencia offline mantem reenvio e informa falha sem perder dados em escala $escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      final conectado = ValueNotifier(false);
      addTearDown(fila.dispose);
      addTearDown(conectado.dispose);
      await fila.registrar([mensagem('offline')]);
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reenvios = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: PendenciasImpressao(
          fila: fila,
          conexao: conectado,
          conectado: () => conectado.value,
          reenviar: (_) async {
            reenvios++;
            throw StateError(
                'Servidor indisponível. A impressão continua salva.');
          },
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
          find.byKey(const ValueKey('reenviar_offline')), 200);
      await tester.pumpAndSettle();
      expect(
          find.text(
              'Sem conexão com o servidor. Impressão salva para reenvio.'),
          findsOneWidget);
      final acao = find.byKey(const ValueKey('reenviar_offline'));
      await tester.ensureVisible(acao);
      await tester.pumpAndSettle();
      await tester.tap(acao);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reenviar').last);
      await tester.pumpAndSettle();
      expect(reenvios, 1);
      expect(fila.itens.single.mensagem, mensagem('offline'));
      expect(find.text('Servidor indisponível. A impressão continua salva.'),
          findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Reenviar'), findsOneWidget);
      conectado.value = true;
      await tester.pumpAndSettle();
      expect(find.text('Impressão salva. Aguardando envio ao servidor.'),
          findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
      'reenvio em andamento bloqueia toques repetidos e mantem pendencia',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('uma-vez')]);
    final concluir = Completer<void>();
    var reenvios = 0;
    await tester.pumpWidget(MaterialApp(
        home: PendenciasImpressao(
      fila: fila,
      reenviar: (_) async {
        reenvios++;
        await concluir.future;
      },
    )));
    final acao = find.byKey(const ValueKey('reenviar_uma-vez'));
    final abrir = tester.widget<FilledButton>(acao).onPressed!;
    abrir();
    abrir();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    final confirmar = tester
        .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Reenviar').last)
        .onPressed!;
    confirmar();
    confirmar();
    await tester.pumpAndSettle();
    expect(reenvios, 1);
    expect(fila.itens, hasLength(1));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Reenviando…'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Excluir'))
            .onPressed,
        isNull);
    concluir.complete();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(FilledButton, 'Reenviar'), findsOneWidget);
    expect(fila.itens, hasLength(1));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pedido ainda sem gravacao nao permite reenvio manual',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('gravando')],
        estado: EstadoImpressao.aguardandoPedido);
    await tester.pumpWidget(MaterialApp(
        home: PendenciasImpressao(
            fila: fila, reenviar: (_) async => fail('Pedido nao confirmado'))));
    expect(find.widgetWithText(FilledButton, 'Reenviar'), findsNothing);
    expect(fila.itens.single.estado, EstadoImpressao.aguardandoPedido);
    await tester.pumpWidget(const SizedBox());
  });

  for (final escala in [1.0, 2.0]) {
    testWidgets(
        'pendencia exige confirmacao antes de reimprimir em escala $escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      await fila.registrar([
        jsonEncode({
          'idRequisicao': 'pizza',
          'tipoImpressao': '1',
          'tipo': 'Comanda',
          'comanda': 'Comanda: 3',
          'numeroPedido': '10679',
          'nomedopc': 'Cozinha',
          'produtos': [
            {'nome': 'Pizza de queijos especiais', 'quantidade': 1}
          ],
        })
      ]);
      await fila.registrarErro('pizza', 'Impressao anterior sem confirmacao');
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reenvios = 0;
      await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: PendenciasImpressao(
            fila: fila,
            reenviar: (_) async {
              reenvios++;
            }),
      ));
      await tester.pumpAndSettle();
      final reenviar = find.byKey(const ValueKey('reenviar_pizza'));
      await tester.scrollUntilVisible(reenviar, 200);
      await tester.pumpAndSettle();
      await tester.tap(reenviar);
      await tester.pumpAndSettle();
      expect(reenvios, 0);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(reenvios, 0);
      await tester.tap(reenviar);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Reenviar').last);
      await tester.pumpAndSettle();
      expect(reenvios, 1);
      expect(fila.itens, hasLength(1));
      await tester.ensureVisible(find.text('Recebido na cozinha'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Recebido na cozinha'));
      await tester.pumpAndSettle();
      expect(fila.itens, hasLength(1));
      await tester.tap(find.widgetWithText(FilledButton, 'Recebido'));
      await tester.pumpAndSettle();
      expect(fila.itens, isEmpty);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('impressao pendente com produto incompleto nao derruba a tela',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([
      jsonEncode({
        'idRequisicao': 'produto-incompleto',
        'tipoImpressao': '1',
        'tipo': 'Comanda',
        'comanda': 'Comanda: 8',
        'produtos': [
          'linha antiga',
          42,
          {'nome': 'Refrigerante'}
        ],
      })
    ]);

    await tester.pumpWidget(MaterialApp(
      home: PendenciasImpressao(fila: fila, reenviar: (_) async {}),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Comanda: 8'), findsOneWidget);
    expect(find.text('1x Refrigerante'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('excluir remove pendencia local somente depois da confirmacao',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([mensagem('ja-impressa')]);
    await fila.registrarErro('ja-impressa', 'Servidor indisponivel');

    await tester.pumpWidget(MaterialApp(
      home: PendenciasImpressao(fila: fila, reenviar: (_) async {}),
    ));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    expect(fila.itens, hasLength(1));
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(fila.itens, hasLength(1));

    await tester.tap(find.widgetWithText(TextButton, 'Excluir'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Excluir'));
    await tester.pumpAndSettle();

    expect(fila.itens, isEmpty);
    expect(find.text('Nenhuma impressão pendente'), findsOneWidget);
    await fila.registrar([mensagem('ja-impressa')]);
    expect(fila.itens, isEmpty);
    expect(tester.takeException(), isNull);
  });

  for (final (largura, escala, escuro) in [
    (430.0, 1.0, false),
    (320.0, 2.0, true),
    (1024.0, 1.0, false),
  ]) {
    testWidgets('conferencia de entregador legivel em $largura, fonte $escala',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      final payload = jsonEncode({
        'idRequisicao': 'entregador-243',
        'tipoImpressao': '3',
        'protocoloImpressao': 2,
        'comanda': 'Delivery 243',
        'numeroPedido': 3,
        'nomedopc': 'DESKTOP-IMNI62S',
        'produtos': [
          {'nome': 'Pizza Doce 1', 'quantidade': 1.0}
        ],
      });
      await fila.registrar([payload], servidor: '192.168.2.113:9980');
      tester.view.physicalSize = Size(largura, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var reenvios = 0;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(
            colorSchemeSeed: const Color(0xFF69558E),
            brightness: escuro ? Brightness.dark : Brightness.light),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(escala)),
          child: child!,
        ),
        home: RepaintBoundary(
          key: const ValueKey('captura'),
          child: PendenciasImpressao(
            fila: fila,
            conectado: () => false,
            mensagemConexao: () =>
                'O servidor recusou a conexão. Confira no PC se a conexão (Local/Online) e a empresa são as mesmas do celular.',
            reenviar: (_) async {
              reenvios++;
            },
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await capturarTela(tester, 'painel_impressoes_${largura}_fonte_$escala');
      await tester.scrollUntilVisible(find.text('Entregador'), 200);
      await tester.pumpAndSettle();
      expect(find.text('1x Pizza Doce 1'), findsOneWidget);
      expect(find.text('Recebido na cozinha'), findsNothing);
      final reenviar = find.byKey(const ValueKey('reenviar_entregador-243'));
      await tester.ensureVisible(reenviar);
      await tester.pumpAndSettle();
      expect(tester.getSize(reenviar).height, greaterThanOrEqualTo(50));
      final detalhes = find.text('Detalhes da impressão');
      await tester.ensureVisible(detalhes);
      await tester.pumpAndSettle();
      await tester.tap(detalhes);
      await tester.pumpAndSettle();
      expect(find.text('Servidor: 192.168.2.113:9980'), findsOneWidget);
      expect(find.text('Computador: DESKTOP-IMNI62S'), findsOneWidget);
      expect(reenvios, 0);
      expect(fila.itens.single.mensagem, payload);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('busca filtra a conferencia sem alterar nem reenviar a fila',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final fila = FilaImpressao();
    addTearDown(fila.dispose);
    await fila.registrar([
      for (var i = 1; i <= 4; i++)
        jsonEncode({
          'idRequisicao': 'busca-$i',
          'tipoImpressao': '1',
          'protocoloImpressao': 2,
          'comanda': 'Comanda: $i',
          'produtos': [
            {'nome': i == 4 ? 'Suco de laranja' : 'Pizza', 'quantidade': 1}
          ],
        }),
    ]);
    final mensagens = fila.itens.map((item) => item.mensagem).toList();
    await tester.pumpWidget(MaterialApp(
        home: PendenciasImpressao(
      fila: fila,
      reenviar: (_) async => fail('Busca não deve reenviar'),
    )));
    await tester.enterText(find.byType(TextField), 'LARANJA');
    await tester.pumpAndSettle();
    expect(find.text('1x Suco de laranja'), findsOneWidget);
    expect(find.text('1x Pizza'), findsNothing);
    await tester.enterText(find.byType(TextField), 'inexistente');
    await tester.pumpAndSettle();
    expect(find.text('Nenhum comprovante encontrado nesta busca.'),
        findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    expect(fila.itens.map((item) => item.mensagem), mensagens);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  group('atalhos de impressoes pendentes', () {
    testWidgets('envio automatico nao pode ser apagado apenas no celular',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      await fila.registrar([mensagem('automatica')]);
      await fila.iniciarEnvio('automatica');
      await tester.pumpWidget(MaterialApp(
        home: PendenciasImpressao(fila: fila, reenviar: (_) async {}),
      ));
      expect(find.text('Recebido na cozinha'), findsNothing);
      expect(find.text('Reenviar'), findsOneWidget);
      expect(fila.itens.single.id, 'automatica');
    });

    testWidgets('card mostra o resumo das pendencias', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      var abriu = false;
      await fila.registrar([mensagem('atalho-card')]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CartaoPendenciasImpressao(
              fila: fila,
              onAbrir: (_) => abriu = true,
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final card = find.byKey(const ValueKey('card_pendencias_impressao'));
      expect(card, findsOneWidget);
      expect(find.text('Impressões Pendentes'), findsOneWidget);
      expect(find.text('1 impressão aguardando'), findsOneWidget);
      await tester.tap(card);
      expect(abriu, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('botao flutuante fica no lado esquerdo', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fila = FilaImpressao();
      addTearDown(fila.dispose);
      var abriu = false;
      await fila.registrar([mensagem('atalho-fab')]);

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          floatingActionButton: BotaoFlutuantePendenciasImpressao(
            tag: 'teste',
            fila: fila,
            onAbrir: (_) => abriu = true,
          ),
          floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
          body: const SizedBox.expand(),
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      final botao =
          find.byKey(const ValueKey('botao_pendencias_impressao_teste'));
      expect(botao, findsOneWidget);
      expect(tester.getRect(botao).left, lessThan(40));
      await tester.tap(botao);
      expect(abriu, isTrue);
      expect(tester.takeException(), isNull);
    });
  });
}
