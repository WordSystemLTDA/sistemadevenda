import 'dart:async';

import 'package:app/src/modulos/voz/cache_disponibilidade_voz.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'consultas simultaneas compartilham o pedido e o sucesso por 30 segundos',
      () async {
    var agora = DateTime(2026, 11, 26, 20);
    final cache = CacheDisponibilidadeVoz(agora: () => agora);
    final resposta = Completer<bool>();
    var chamadas = 0;
    Future<bool> consultar() {
      chamadas++;
      return resposta.future;
    }

    final a = cache.consultar('servidor|empresa|usuario', consultar);
    final b = cache.consultar('servidor|empresa|usuario', consultar);
    expect(identical(a, b), isTrue);
    resposta.complete(true);
    expect(await a, isTrue);
    expect(
        await cache.consultar('servidor|empresa|usuario', consultar), isTrue);
    expect(chamadas, 1);
    agora = agora.add(const Duration(seconds: 31));
    await cache.consultar('servidor|empresa|usuario', consultar);
    expect(chamadas, 2);
  });

  test(
      '503 ou falha de transporte espera dois minutos e permite consulta forcada',
      () async {
    var agora = DateTime(2026, 11, 26, 20);
    final cache = CacheDisponibilidadeVoz(agora: () => agora);
    var chamadas = 0;
    Future<bool> falhar() async {
      chamadas++;
      throw StateError('Servico indisponivel');
    }

    expect(await cache.consultar('a', falhar), isFalse);
    agora = agora.add(const Duration(seconds: 60));
    expect(await cache.consultar('a', falhar), isFalse);
    expect(chamadas, 1);
    agora = agora.add(const Duration(seconds: 61));
    expect(await cache.consultar('a', falhar), isFalse);
    expect(chamadas, 2);
    expect(await cache.consultar('a', () async => true, forcar: true), isTrue);
  });

  test(
      'outra empresa ou servidor nao herda o resultado e respostas antigas sao ignoradas',
      () async {
    final cache = CacheDisponibilidadeVoz();
    final antiga = Completer<bool>();
    final consultaAntiga =
        cache.consultar('servidor1|empresa1', () => antiga.future);
    expect(await cache.consultar('servidor2|empresa2', () async => false),
        isFalse);
    antiga.complete(true);
    expect(await consultaAntiga, isFalse);
    expect(
        await cache.consultar('servidor2|empresa2', () async => true), isFalse);
  });

  test(
      'invalidar descarta resposta em voo e permite ler configuracao atualizada',
      () async {
    final cache = CacheDisponibilidadeVoz();
    final antiga = Completer<bool>();
    final consultaAntiga = cache.consultar('a', () => antiga.future);
    cache.invalidar();
    expect(await cache.consultar('a', () async => true), isTrue);
    antiga.complete(false);
    expect(await consultaAntiga, isFalse);
    expect(await cache.consultar('a', () async => false), isTrue);
  });
}
