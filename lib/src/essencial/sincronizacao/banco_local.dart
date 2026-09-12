import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Dados de trabalho usam SQLite; preferencias continuam apenas para ajustes.
class BancoLocal {
  static BancoLocal? instancia;
  final Database db;
  String servidor = '';

  BancoLocal(this.db);

  static Future<BancoLocal> abrir({DatabaseFactory? factory, String? path}) async {
    final fabrica = factory ?? databaseFactory;
    final banco = await fabrica.openDatabase(
      path ?? '${await fabrica.getDatabasesPath()}/garcom_offline.db',
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA synchronous = FULL');
        },
        onCreate: (db, _) async {
          await db.execute('CREATE TABLE documentos ('
              'chave TEXT PRIMARY KEY, valor TEXT NOT NULL)');
          await db.execute('CREATE TABLE consultas ('
              'escopo TEXT NOT NULL, chave TEXT NOT NULL, valor TEXT NOT NULL, '
              'atualizado INTEGER NOT NULL, PRIMARY KEY (escopo, chave))');
          await db.execute('CREATE TABLE operacoes ('
              'id TEXT PRIMARY KEY, escopo TEXT NOT NULL, '
              'atendimento TEXT NOT NULL, acao TEXT NOT NULL, '
              'estado TEXT NOT NULL, dados TEXT NOT NULL, '
              'impressoes TEXT NOT NULL, destino TEXT NOT NULL, '
              'criado INTEGER NOT NULL, tentativas INTEGER NOT NULL DEFAULT 0, '
              'proxima INTEGER NOT NULL DEFAULT 0, erro TEXT, resposta TEXT)');
          await db.execute('CREATE INDEX fila_por_escopo '
              'ON operacoes (escopo, estado, criado)');
        },
      ),
    );
    return BancoLocal(banco);
  }

  static String novoId() => List.generate(
      24, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join();

  static String escopo(String servidor, String empresa, String usuario) =>
      jsonEncode([servidor, empresa, usuario]);

  String get chaveCarrinhos => 'carrinhos:$servidor';

  static Future<String?> lerDocumento(DatabaseExecutor db, String chave) async {
    final linhas = await db.query('documentos',
        where: 'chave = ?', whereArgs: [chave], limit: 1);
    return linhas.firstOrNull?['valor'] as String?;
  }

  static Future<void> gravarDocumento(
          DatabaseExecutor db, String chave, String valor) async =>
      db.insert('documentos', {'chave': chave, 'valor': valor},
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<String?> ler(String chave) => lerDocumento(db, chave);
  Future<void> gravar(String chave, String valor) =>
      gravarDocumento(db, chave, valor);

  Future<void> migrarPreferencia(String origem, String destino) async {
    final prefs = await SharedPreferences.getInstance();
    final valor = prefs.getString(origem);
    await db.transaction((tx) async {
      if (await lerDocumento(tx, destino) == null && valor != null) {
        await gravarDocumento(tx, destino, valor);
      }
    });
    // Remove somente depois do commit, nunca em caso de erro de armazenamento.
    if (valor != null && !await prefs.remove(origem)) {
      throw StateError('Nao foi possivel concluir a migracao dos dados locais.');
    }
  }

  Future<List<Map<String, Object?>>> operacoes(String escopo) => db.query(
        'operacoes',
        where: 'escopo = ? AND estado NOT IN (?, ?)',
        whereArgs: [escopo, 'concluido', 'arquivado'],
        orderBy: 'criado, rowid',
      );

  Future<void> atualizarOperacao(String id, Map<String, Object?> campos) async {
    await db.update('operacoes', campos, where: 'id = ?', whereArgs: [id]);
  }

  Future<String> guardarPedido({
    required String escopo,
    required String chaveCarrinho,
    required String atendimento,
    required List<Map<String, dynamic>> itens,
    required Map<String, dynamic> dados,
    required List<String> impressoes,
    required String destino,
    bool recorrentes = false,
  }) async {
    final id = novoId();
    final campo = recorrentes ? 'recorrentes' : 'itens';
    await db.transaction((tx) async {
      final carrinhos = jsonDecode(
          await lerDocumento(tx, chaveCarrinhos) ?? '{}') as Map<String, dynamic>;
      final carrinho = carrinhos[chaveCarrinho] as Map<String, dynamic>?;
      if (itens.isEmpty || carrinho == null ||
          carrinho['encerrado'] == true || carrinho['bloqueado'] == true ||
          jsonEncode(carrinho[campo]) != jsonEncode(itens)) {
        throw StateError('O carrinho mudou. Confira os produtos novamente.');
      }
      await tx.insert('operacoes', {
        'id': id, 'escopo': escopo, 'atendimento': atendimento,
        'acao': 'produtos', 'estado': 'pendente',
        'dados': jsonEncode(dados), 'impressoes': jsonEncode(impressoes),
        'destino': destino, 'criado': DateTime.now().millisecondsSinceEpoch,
      });
      carrinho[campo] = [];
      if (recorrentes) carrinho['recorrentesImportados'] = true;
      await gravarDocumento(tx, chaveCarrinhos, jsonEncode(carrinhos));
    });
    return id;
  }

  Future<void> guardarConsulta(String escopo, String chave, Object? valor) async {
    await db.insert('consultas', {
      'escopo': escopo, 'chave': chave, 'valor': jsonEncode(valor),
      'atualizado': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, Object?>?> consulta(String escopo, String chave) async =>
      (await db.query('consultas', where: 'escopo = ? AND chave = ?',
          whereArgs: [escopo, chave], limit: 1)).firstOrNull;
}
