import 'dart:convert';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/armazenamento_carrinhos.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/impressao_preparo_test.dart' show produto;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  late BancoLocal banco;
  final armazenamento = ArmazenamentoCarrinhos.instancia;
  const contexto = ContextoCarrinho(
      empresa: '32', tipo: 'comanda', idAtendimento: '104', idRecurso: '4');

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    banco = await BancoLocal.abrir(
        factory: databaseFactoryFfi, path: inMemoryDatabasePath);
    BancoLocal.instancia = banco;
    banco.servidor = 'cozinha';
    await armazenamento.alterar(contexto, (itens) => itens.add(produto()));
  });

  tearDown(() async {
    BancoLocal.instancia = null;
    await banco.db.close();
  });

  Future<void> fechar() => armazenamento.conferirRascunhosNoServidor(
      chaveDocumento: banco.chaveCarrinhos,
      empresa: '32',
      identidadesConsultadas: {'104': '104'},
      atendimentos: {});

  Future<void> conferirStatus(String status) =>
      armazenamento.conferirRascunhosNoServidor(
          chaveDocumento: banco.chaveCarrinhos,
          empresa: '32',
          identidadesConsultadas: {
            '104': '104'
          },
          atendimentos: {
            '104': {'status': status}
          });

  Future<void> impedirEscrita() => banco.db
      .execute("CREATE TRIGGER impedir_escrita BEFORE INSERT ON documentos "
          "BEGIN SELECT RAISE(ABORT, 'escrita inesperada'); END");

  for (final status in ['Andamento', 'Fechamento']) {
    test('snapshot repetido $status nao regrava nem notifica', () async {
      var notificacoes = 0;
      void notificar() => notificacoes++;
      armazenamento.addListener(notificar);
      addTearDown(() => armazenamento.removeListener(notificar));

      await conferirStatus(status);
      expect(notificacoes, 1);
      final antes = await banco.ler(banco.chaveCarrinhos);
      await impedirEscrita();

      await conferirStatus(status);
      await conferirStatus(status);

      expect(notificacoes, 1);
      expect(await banco.ler(banco.chaveCarrinhos), antes);
      final registro = (jsonDecode(antes!) as Map)[contexto.chave];
      expect(registro['bloqueado'], status != 'Andamento');
      expect(registro['itens'], hasLength(1));
    });
  }

  test('fechamento repetido nao regrava nem notifica', () async {
    await fechar();
    final antes = await banco.ler(banco.chaveCarrinhos);
    var notificacoes = 0;
    void notificar() => notificacoes++;
    armazenamento.addListener(notificar);
    addTearDown(() => armazenamento.removeListener(notificar));
    await impedirEscrita();

    await fechar();
    await fechar();

    expect(notificacoes, 0);
    expect(await banco.ler(banco.chaveCarrinhos), antes);
    final registro = (jsonDecode(antes!) as Map)[contexto.chave];
    expect(registro['encerrado'], true);
    expect(registro['encerradoConfirmado'], true);
    expect(registro['itens'], hasLength(1));
  });

  test('mudanca real de status atualiza bloqueio e notifica uma vez', () async {
    await conferirStatus('Fechamento');
    expect(
        await armazenamento.alterar(contexto, (itens) => itens.clear()), false);
    var notificacoes = 0;
    void notificar() => notificacoes++;
    armazenamento.addListener(notificar);
    addTearDown(() => armazenamento.removeListener(notificar));

    await conferirStatus('Andamento');
    await conferirStatus('Andamento');

    expect(notificacoes, 1);
    final carrinhos = jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}');
    expect(carrinhos[contexto.chave]['bloqueado'], false);
    expect(carrinhos[contexto.chave]['itens'], hasLength(1));
  });

  test('falha ao persistir novo status nao notifica nem altera rascunho',
      () async {
    await conferirStatus('Andamento');
    final antes = await banco.ler(banco.chaveCarrinhos);
    var notificacoes = 0;
    void notificar() => notificacoes++;
    armazenamento.addListener(notificar);
    addTearDown(() => armazenamento.removeListener(notificar));
    await impedirEscrita();

    await expectLater(conferirStatus('Fechamento'), throwsA(anything));

    expect(notificacoes, 0);
    expect(await banco.ler(banco.chaveCarrinhos), antes);
  });

  test('fechamento preserva rascunho e resposta antiga nao o reabre', () async {
    await fechar();
    await conferirStatus('Andamento');
    await armazenamento.atualizarStatus('32', '104', 'Andamento');
    await armazenamento.sincronizarRecurso(
        empresa: '32',
        tipo: 'comanda',
        idRecurso: '4',
        idAtendimento: '104',
        aberto: true);
    expect(
        await armazenamento.alterar(contexto, (itens) => itens.clear()), false);
    final carrinhos = jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}');
    expect(carrinhos[contexto.chave]['itens'], hasLength(1));
    expect(carrinhos[contexto.chave]['encerrado'], true);
    expect(carrinhos[contexto.chave]['encerradoConfirmado'], true);
  });

  test('excluir rascunho bloqueado arquiva copia antes de limpar', () async {
    await fechar();
    await armazenamento.arquivarRascunhoBloqueado(
        contexto: contexto, chaveDocumento: banco.chaveCarrinhos);
    final arquivos = await banco.db.query('documentos',
        where: 'chave LIKE ?', whereArgs: ['rascunho-arquivado:%']);
    expect(arquivos, hasLength(1));
    final salvo = jsonDecode(arquivos.single['valor'] as String);
    expect(salvo['carrinho']['itens'], hasLength(1));
    final carrinhos = jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}');
    expect(carrinhos[contexto.chave]['itens'], isEmpty);
  });

  test('falha no arquivo preserva integralmente os itens bloqueados', () async {
    await fechar();
    await banco.db
        .execute("CREATE TRIGGER falhar_arquivo BEFORE INSERT ON documentos "
            "WHEN NEW.chave LIKE 'rascunho-arquivado:%' "
            "BEGIN SELECT RAISE(ABORT, 'disk full'); END");
    await expectLater(
        armazenamento.arquivarRascunhoBloqueado(
            contexto: contexto, chaveDocumento: banco.chaveCarrinhos),
        throwsA(anything));
    final carrinhos = jsonDecode(await banco.ler(banco.chaveCarrinhos) ?? '{}');
    expect(carrinhos[contexto.chave]['itens'], hasLength(1));
  });

  test('snapshot nao encerra carrinho criado depois nem de outra empresa',
      () async {
    var notificacoes = 0;
    void notificar() => notificacoes++;
    armazenamento.addListener(notificar);
    addTearDown(() => armazenamento.removeListener(notificar));
    await impedirEscrita();
    await armazenamento.conferirRascunhosNoServidor(
        chaveDocumento: banco.chaveCarrinhos,
        empresa: '32',
        identidadesConsultadas: {'103': '103'},
        atendimentos: {});
    expect(await armazenamento.listar(contexto), hasLength(1));
    await armazenamento.conferirRascunhosNoServidor(
        chaveDocumento: banco.chaveCarrinhos,
        empresa: '33',
        identidadesConsultadas: {'104': '104'},
        atendimentos: {});
    expect(await armazenamento.listar(contexto), hasLength(1));
    expect(notificacoes, 0);
  });
}
