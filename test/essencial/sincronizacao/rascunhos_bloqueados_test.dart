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

  test('fechamento preserva rascunho e resposta antiga nao o reabre', () async {
    await fechar();
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
  });
}
