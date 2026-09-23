import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/src/essencial/api/socket/atualizacao_agrupada.dart';
import 'package:app/src/essencial/api/socket/monitor_atualizacao_tela.dart';

void main() {
  test('rajada faz uma leitura imediata e outra com o ultimo filtro', () async {
    final fila = AtualizacaoAgrupada();
    final primeira = Completer<void>();
    final executadas = <int>[];
    final chamadas = <Future<void>>[
      fila.executar(() async {
        executadas.add(0);
        await primeira.future;
      }),
    ];
    for (var filtro = 1; filtro <= 50; filtro++) {
      final atual = filtro;
      chamadas.add(fila.executar(() async => executadas.add(atual)));
    }
    expect(executadas, [0]);
    primeira.complete();
    await Future.wait(chamadas);
    expect(executadas, [0, 50]);
    expect(fila.emAndamento, isFalse);
  });

  test('erro na primeira consulta nao perde evento recebido durante ela',
      () async {
    final fila = AtualizacaoAgrupada();
    final primeira = Completer<void>();
    var atualizado = false;
    final inicio = fila.executar(() => primeira.future);
    final fim = fila.executar(() async => atualizado = true);
    primeira.completeError(StateError('rede caiu'));
    await Future.wait([inicio, fim]);
    expect(atualizado, isTrue);
  });

  test('fila aceita nova tentativa depois de falhar', () async {
    final fila = AtualizacaoAgrupada();
    await expectLater(fila.executar(() async => throw StateError('offline')),
        throwsStateError);
    var tentativas = 0;
    await fila.executar(() async => tentativas++);
    expect(tentativas, 1);
  });

  test('dispose cancela leitura pendente sem abandonar future atual', () async {
    final fila = AtualizacaoAgrupada();
    final primeira = Completer<void>();
    var pendente = false;
    final inicio = fila.executar(() => primeira.future);
    final fim = fila.executar(() async => pendente = true);
    fila.dispose();
    primeira.complete();
    await Future.wait([inicio, fim]);
    expect(pendente, isFalse);
  });

  testWidgets('monitor reconcilia eventos perdidos somente na tela ativa',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var ativa = true;
    var leituras = 0;
    final monitor = MonitorAtualizacaoTela(
      atualizar: () async => leituras++,
      estaAtiva: () => ativa,
    );
    await tester.pump(const Duration(seconds: 5));
    expect(leituras, 1);
    ativa = false;
    await tester.pump(const Duration(seconds: 5));
    expect(leituras, 1);
    ativa = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 10));
    expect(leituras, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(leituras, 2);
    monitor.dispose();
    await tester.pump(const Duration(seconds: 5));
    expect(leituras, 2);
  });

  testWidgets('monitor nao acumula polling enquanto o servidor esta lento',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final resposta = Completer<void>();
    var leituras = 0;
    final monitor = MonitorAtualizacaoTela(
      atualizar: () async {
        leituras++;
        await resposta.future;
      },
      estaAtiva: () => true,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(seconds: 30));
    expect(leituras, 1);
    resposta.complete();
    await tester.pump();
    expect(leituras, 1);
    monitor.dispose();
  });

  testWidgets('evento renova intervalo e evita polling logo apos consultar',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    var leituras = 0;
    final monitor = MonitorAtualizacaoTela(
      atualizar: () async => leituras++,
      estaAtiva: () => true,
    );
    await tester.pump(const Duration(milliseconds: 4900));
    await monitor.solicitar();
    expect(leituras, 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(leituras, 1);
    await tester.pump(const Duration(milliseconds: 4900));
    expect(leituras, 2);
    monitor.dispose();
  });

  testWidgets('evento recebido durante consulta nao e perdido nem multiplicado',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final resposta = Completer<void>();
    var leituras = 0;
    final monitor = MonitorAtualizacaoTela(
      atualizar: () async {
        leituras++;
        if (leituras == 1) await resposta.future;
      },
      estaAtiva: () => true,
    );
    final chamadas = <Future<void>>[monitor.solicitar()];
    for (var i = 0; i < 20; i++) {
      chamadas.add(monitor.solicitar());
    }
    await tester.pump(const Duration(seconds: 30));
    expect(leituras, 1);
    resposta.complete();
    await Future.wait(chamadas);
    expect(leituras, 2);
    await tester.pump(const Duration(seconds: 4));
    expect(leituras, 2);
    await tester.pump(const Duration(seconds: 1));
    expect(leituras, 3);
    monitor.dispose();
  });

  testWidgets(
      'consulta pendente nao inicia ao apagar a tela e retoma ao voltar',
      (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final resposta = Completer<void>();
    var leituras = 0;
    final monitor = MonitorAtualizacaoTela(
      atualizar: () async {
        leituras++;
        if (leituras == 1) await resposta.future;
      },
      estaAtiva: () => true,
    );
    final primeira = monitor.solicitar();
    final pendente = monitor.solicitar();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    resposta.complete();
    await Future.wait([primeira, pendente]);
    await tester.pump(const Duration(seconds: 30));
    expect(leituras, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(leituras, 2);
    monitor.dispose();
  });

  testWidgets('trocar de tela descarta a releitura pendente', (tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    final resposta = Completer<void>();
    var leituras = 0;
    var ativa = true;
    final monitor = MonitorAtualizacaoTela(
      atualizar: () async {
        leituras++;
        await resposta.future;
      },
      estaAtiva: () => ativa,
    );
    final primeira = monitor.solicitar();
    final pendente = monitor.solicitar();
    ativa = false;
    resposta.complete();
    await Future.wait([primeira, pendente]);
    await tester.pump(const Duration(seconds: 30));
    expect(leituras, 1);
    monitor.dispose();
  });
}
