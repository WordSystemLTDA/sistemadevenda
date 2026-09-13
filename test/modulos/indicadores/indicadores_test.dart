import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_modelo.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/indicadores/modelo_indicadores.dart';
import 'package:app/src/modulos/indicadores/servico_indicadores.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Map<String, dynamic> grupo(
        {String dia = '2026-09-12',
        int? hora = 19,
        String canal = 'Comanda',
        String status = 'Andamento',
        int quantidade = 2,
        int centavos = 8500}) =>
    {
      'dia': dia,
      'hora': hora,
      'canal': canal,
      'status': status,
      'quantidade': quantidade,
      'consumo_centavos': centavos,
    };

Map<String, dynamic> relatorio(
        {List<Map<String, dynamic>>? grupos,
        String inicio = '2026-09-12',
        String fim = '2026-09-12',
        DateTime? atualizado}) =>
    {
      'versao': 1,
      'inicio': inicio,
      'fim': fim,
      'atualizado_em': (atualizado ?? DateTime.now()).toIso8601String(),
      'grupos': grupos ?? [grupo()],
    };

UsuarioProvedor administrador() => UsuarioProvedor()
  ..setUsuario(UsuarioModelo(
      id: '1', empresa: '32', nivel: '1', email: 'gestor', senha: 'teste'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  test('permissao segue niveis administrativos existentes', () {
    expect(podeVerIndicadores(null), isFalse);
    expect(podeVerIndicadores(UsuarioModelo(nivel: '5')), isFalse);
    expect(podeVerIndicadores(UsuarioModelo(nivel: '0')), isTrue);
    expect(podeVerIndicadores(administrador().usuario), isTrue);
  });

  test('agregados, filtros, pico, cancelamentos e dias sem movimento', () {
    final modelo =
        ModeloIndicadores.fromMap(relatorio(inicio: '2026-09-10', grupos: [
      grupo(),
      grupo(
          canal: 'Mesa',
          hora: 20,
          quantidade: 3,
          status: 'Fechamento',
          centavos: 15000),
      grupo(canal: 'Balcao', hora: 20, quantidade: 1, centavos: 2000),
      grupo(status: 'Cancelada', quantidade: 8, centavos: 99999),
    ]));
    final resumo = modelo.resumir(CanalIndicadores.todos);
    expect(resumo.quantidade, 6);
    expect(resumo.cancelados, 8);
    expect(resumo.consumoCentavos, 25500);
    expect(resumo.emAndamento, 2);
    expect(resumo.emFechamento, 3);
    expect(resumo.pico?.posicao, 20);
    expect(resumo.pico?.quantidade, 4);
    expect(resumo.porHora.length, 24);
    expect(resumo.porDia.map((p) => p.quantidade), [0, 0, 6]);
    expect(modelo.resumir(CanalIndicadores.mesa).quantidade, 3);
    expect(modelo.resumir(CanalIndicadores.balcao).consumoCentavos, 2000);
  });

  test('sem pico inventado quando nao existe horario ou movimento', () {
    expect(
        ModeloIndicadores.fromMap(relatorio(grupos: []))
            .resumir(CanalIndicadores.todos)
            .pico,
        isNull);
    final resumo =
        ModeloIndicadores.fromMap(relatorio(grupos: [grupo(hora: null)]))
            .resumir(CanalIndicadores.todos);
    expect(resumo.quantidade, 2);
    expect(resumo.pico, isNull);
  });

  test('dias civis independem de horas na mudanca historica de fuso', () {
    expect(
        diasEntreDatas(DateTime(2018, 11, 3, 23), DateTime(2018, 11, 4, 1)), 1);
    expect(diasEntreDatas(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 2);
  });

  group('consulta autenticada e cache', () {
    late DioCliente api;
    late BancoLocal banco;
    late UsuarioProvedor usuarios;
    late ServicoIndicadores servico;
    String servidor = 'http://servidor/';
    Object? falha;
    var pedidos = 0;
    Completer<void>? espera;
    Map<String, dynamic> retorno = {};
    final data = DateTime(2026, 9, 12);
    String chave() =>
        'indicadores:${BancoLocal.escopo(servidor, usuarios.usuario!.empresa!, usuarios.usuario!.id!)}';

    setUp(() async {
      falha = null;
      espera = null;
      pedidos = 0;
      servidor = 'http://servidor/';
      retorno = relatorio();
      SharedPreferences.setMockInitialValues({});
      banco = await BancoLocal.abrir(
          factory: databaseFactoryFfi, path: inMemoryDatabasePath);
      usuarios = administrador();
      api = DioCliente();
      api.cliente.interceptors.clear();
      api.cliente.interceptors
          .add(InterceptorsWrapper(onRequest: (op, handler) async {
        pedidos++;
        expect(op.extra['semCache'], isTrue);
        expect(op.extra['servidorFixo'], servidor);
        expect(op.queryParameters, isEmpty);
        expect(op.data['senha'], 'teste');
        await espera?.future;
        if (falha is int) {
          handler.reject(DioException(
              requestOptions: op,
              type: DioExceptionType.badResponse,
              response:
                  Response(requestOptions: op, statusCode: falha as int)));
        } else if (falha == 'offline') {
          handler.reject(DioException(
              requestOptions: op, type: DioExceptionType.connectionError));
        } else {
          handler.resolve(Response(
              requestOptions: op,
              statusCode: 200,
              data: {'sucesso': true, 'resultado': retorno}));
        }
      }));
      servico = ServicoIndicadores(api, usuarios,
          banco: banco, servidor: () async => servidor);
    });
    tearDown(() async {
      api.cliente.close(force: true);
      await banco.db.close();
      usuarios.dispose();
    });

    test(
        'online salva apenas resultado; offline usa ultima consulta do mesmo periodo',
        () async {
      expect((await servico.consultar(data, data)).offline, isFalse);
      final salvo = await banco.ler(chave());
      expect(salvo, isNot(contains('senha')));
      falha = 'offline';
      expect((await servico.consultar(data, data)).offline, isTrue);
      falha = null;
      expect((await servico.consultar(data, data)).offline, isFalse);
      expect(pedidos, 3);
    });

    test('cache nao cruza periodo, servidor ou usuario', () async {
      await servico.consultar(data, data);
      falha = 'offline';
      await expectLater(
          servico.consultar(data.subtract(const Duration(days: 1)), data),
          throwsA(isA<FalhaIndicadores>()));
      servidor = 'http://outro/';
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
      servidor = 'http://servidor/';
      usuarios.setUsuario(
          UsuarioModelo(id: '2', empresa: '32', nivel: '1', senha: 'teste'));
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
    });

    test('cache expirado ou corrompido nao e apresentado', () async {
      await banco.gravar(
          chave(),
          jsonEncode(relatorio(
              atualizado: DateTime.now().subtract(const Duration(days: 2)))));
      falha = 'offline';
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
      await banco.gravar(chave(), '{corrompido');
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
    });

    for (final status in [401, 403]) {
      test('HTTP $status invalida cache sem exibir relatorio antigo', () async {
        await servico.consultar(data, data);
        falha = status;
        await expectLater(
            servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
        expect(await banco.ler(chave()), '');
        falha = 'offline';
        await expectLater(
            servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
      });
    }
    for (final status in [404, 500]) {
      test('HTTP $status nao vira sucesso offline', () async {
        await servico.consultar(data, data);
        falha = status;
        await expectLater(
            servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
      });
    }

    test('usuario nao administrador nao consulta servidor', () async {
      usuarios.setUsuario(UsuarioModelo(id: '5', empresa: '32', nivel: '5'));
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
      expect(pedidos, 0);
    });

    test('resposta atrasada apos sair da conta nao e mostrada nem guardada',
        () async {
      espera = Completer<void>();
      final antigaChave = chave();
      final futuro = servico.consultar(data, data);
      final verificacao = expectLater(futuro, throwsA(isA<FalhaIndicadores>()));
      await Future<void>.delayed(Duration.zero);
      usuarios.setUsuario(null);
      espera!.complete();
      await verificacao;
      expect(await banco.ler(antigaChave), isNull);
    });

    test('recusa periodo retornado incorretamente e versao desconhecida',
        () async {
      retorno = relatorio(inicio: '2026-09-11');
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FalhaIndicadores>()));
      expect(await banco.ler(chave()), isNull);
      retorno = {...relatorio(), 'versao': 2};
      await expectLater(
          servico.consultar(data, data), throwsA(isA<FormatException>()));
    });
  });
}
