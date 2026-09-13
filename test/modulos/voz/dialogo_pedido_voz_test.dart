import 'dart:async';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/voz/dialogo_pedido_voz.dart';
import 'package:app/src/modulos/voz/gravador_voz.dart';
import 'package:app/src/modulos/voz/pedido_falado.dart';
import 'package:app/src/modulos/voz/servico_pedido_voz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../suporte/captura_tela.dart';
import 'pedido_falado_test.dart' show pizzaDetalhada;

class GravadorTeste extends Fake implements GravadorVoz {
  int inicios = 0, conclusoes = 0, cancelamentos = 0, descartes = 0;
  Object? erro;
  Completer<void>? inicioPendente;
  @override
  Future<void> iniciar() async {
    inicios++;
    if (inicioPendente != null) await inicioPendente!.future;
    if (erro != null) throw erro!;
  }

  @override
  Future<String> concluir() async {
    conclusoes++;
    return '/audio-teste.m4a';
  }

  @override
  Future<void> cancelar() async {
    cancelamentos++;
  }

  @override
  Future<void> dispose() async {
    descartes++;
  }
}

class VozTeste extends Fake implements ServicoPedidoVoz {
  int chamadas = 0, descartes = 0;
  int verificacoes = 0;
  Completer<void>? verificacaoPendente;
  Object? erro;
  Completer<({String texto, Modelowordprodutos item})>? espera;
  @override
  Future<void> verificar() async {
    verificacoes++;
    if (verificacaoPendente != null) await verificacaoPendente!.future;
    if (erro != null) throw erro!;
  }

  @override
  Future<({String texto, Modelowordprodutos item})> interpretar(
      String caminho) async {
    chamadas++;
    return espera != null
        ? await espera!.future
        : (texto: 'Pizza G', item: pizzaDetalhada());
  }

  @override
  void dispose() {
    descartes++;
  }
}

void main() {
  setUpAll(carregarFontesDeTeste);
  late GravadorTeste gravador;
  late VozTeste servico;
  Modelowordprodutos? resultado;
  setUp(() {
    gravador = GravadorTeste();
    servico = VozTeste();
    resultado = null;
  });
  Future<void> abrir(WidgetTester tester,
      {Size tela = const Size(393, 852), double escala = 1}) async {
    tester.view.physicalSize = tela;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(RepaintBoundary(
        key: const ValueKey('captura'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(colorSchemeSeed: Colors.deepPurple),
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(escala)),
              child: child!),
          home: Builder(
              builder: (context) => Scaffold(
                      body: IconButton(
                    tooltip: 'Voz',
                    icon: const Icon(Icons.mic),
                    onPressed: () async {
                      resultado = await showDialog<Modelowordprodutos>(
                          context: context,
                          builder: (_) => DialogoPedidoVoz(
                              atendimento: 'Comanda: 10',
                              servico: servico,
                              gravador: gravador));
                    },
                  ))),
        )));
    await tester.tap(find.byTooltip('Voz'));
    await tester.pumpAndSettle();
  }

  for (final tamanho in [
    const Size(320, 568),
    const Size(393, 852),
    const Size(1024, 768)
  ]) {
    testWidgets('gravacao visivel e sem overflow $tamanho', (tester) async {
      await abrir(tester, tela: tamanho);
      expect(gravador.inicios, 0);
      expect(find.textContaining('OpenAI'), findsOneWidget);
      await tester.tap(find.text('Gravar pedido'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining('Gravando'), findsOneWidget);
      expect(find.text('Concluir e enviar'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capturarTela(tester, 'pedido_voz_${tamanho.width.toInt()}');
      await tester.tap(find.byTooltip('Cancelar pedido por voz'));
      await tester.pumpAndSettle();
      expect(gravador.descartes, 1);
      expect(servico.chamadas, 0);
      expect(resultado, isNull);
    });
  }
  testWidgets('texto ampliado em celular pequeno', (tester) async {
    await abrir(tester, tela: const Size(320, 568), escala: 1.5);
    await tester.ensureVisible(find.text('Gravar pedido'));
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('dois toques em concluir interpretam apenas uma vez',
      (tester) async {
    servico.espera = Completer();
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    await tester.tap(find.text('Concluir e enviar'));
    await tester.tap(find.text('Concluir e enviar'));
    await tester.pump();
    expect(servico.chamadas, 1);
    expect(gravador.conclusoes, 1);
    servico.espera!.complete((texto: 'Pizza', item: pizzaDetalhada()));
    await tester.pumpAndSettle();
    expect(resultado?.id, '1');
  });
  testWidgets('cancelar antes da resposta descarta resultado tardio',
      (tester) async {
    servico.espera = Completer();
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    await tester.tap(find.text('Concluir e enviar'));
    await tester.pump();
    await tester.tap(find.byTooltip('Cancelar pedido por voz'));
    await tester.pumpAndSettle();
    servico.espera!.complete((texto: 'Pizza', item: pizzaDetalhada()));
    await tester.pumpAndSettle();
    expect(resultado, isNull);
    expect(tester.takeException(), isNull);
  });
  testWidgets('sem permissao nao envia audio nem item', (tester) async {
    gravador.erro = const FalhaPedidoVoz('Microfone sem permissão.');
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pumpAndSettle();
    expect(find.text('Microfone sem permissão.'), findsOneWidget);
    expect(servico.chamadas, 0);
    expect(resultado, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sem API configurada nao abre o microfone', (tester) async {
    servico.erro = const FalhaPedidoVoz('Configure a API.');
    await abrir(tester);
    expect(find.text('Configure a API.'), findsOneWidget);
    expect(gravador.inicios, 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('toques repetidos nao abrem verificacoes concorrentes',
      (tester) async {
    servico.erro = const FalhaPedidoVoz('Configure a API.');
    await abrir(tester);
    servico.erro = null;
    servico.verificacaoPendente = Completer<void>();
    await tester.tap(find.text('Tentar novamente'));
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    expect(servico.verificacoes, 2); // Inicial e uma unica repeticao.
    servico.verificacaoPendente!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Gravar pedido'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('limite de tempo cancela em vez de enviar fala cortada',
      (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 61));
    expect(gravador.cancelamentos, 1);
    expect(servico.chamadas, 0);
    expect(find.textContaining('Tempo de gravação'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('ir para segundo plano cancela sem envio', (tester) async {
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(gravador.cancelamentos, 1);
    expect(servico.chamadas, 0);
    expect(resultado, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('sair enquanto aguarda permissao impede gravacao tardia',
      (tester) async {
    gravador.inicioPendente = Completer<void>();
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(find.textContaining('interrompido'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    gravador.inicioPendente!.complete();
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(find.textContaining('Gravando'), findsNothing);
    expect(gravador.cancelamentos, greaterThanOrEqualTo(1));
    expect(servico.chamadas, 0);
    expect(resultado, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('permissao nativa inactive permite continuar ao retornar',
      (tester) async {
    gravador.inicioPendente = Completer<void>();
    await abrir(tester);
    await tester.tap(find.text('Gravar pedido'));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    gravador.inicioPendente!.complete();
    await tester.pump();
    expect(find.textContaining('Gravando'), findsOneWidget);
    expect(gravador.cancelamentos, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
