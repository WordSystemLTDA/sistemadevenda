import 'dart:convert';

import 'package:dio/dio.dart';

import 'banco_local.dart';
import 'cache_consultas.dart';

/// Identidades locais permanecem estaveis mesmo com uma tela/carrinho aberto.
class AtendimentosLocais {
  final BancoLocal banco;
  final String escopo;
  AtendimentosLocais(this.banco, this.escopo);

  static bool local(String id) => id.startsWith('local:');

  Future<Map<String, Object?>?> abertura(String id) async =>
      (await banco.db.query('operacoes',
              where: 'escopo = ? AND atendimento = ? AND acao = ?',
              whereArgs: [escopo, id, 'abertura'], limit: 1))
          .firstOrNull;

  static Map<String, dynamic> dados(Map<String, Object?> op) =>
      jsonDecode(op['dados'] as String) as Map<String, dynamic>;

  static Map<String, dynamic> recibo(Map<String, Object?> op) =>
      jsonDecode(op['resposta'] as String? ?? '{}') as Map<String, dynamic>;

  Future<String> idServidor(String id) async {
    if (!local(id)) return id;
    final op = await abertura(id);
    final real = op == null ? null : recibo(op)['id_comanda_pedido'];
    if (real == null || ['conflito', 'arquivado'].contains(op!['estado'])) {
      throw StateError('Aguarde a confirmacao da abertura para alterar este atendimento.');
    }
    return real.toString();
  }

  Future<String> abrir(Map<String, dynamic> dados, String destino) async {
    final operacao = BancoLocal.novoId();
    final id = 'local:$operacao';
    await banco.db.transaction((tx) async {
      final pendentes = await tx.query('operacoes',
          where: "escopo = ? AND acao = 'abertura' AND estado NOT IN ('concluido', 'arquivado', 'conflito')",
          whereArgs: [escopo]);
      for (final op in pendentes) {
        final anterior = AtendimentosLocais.dados(op);
        if (['id_mesa', 'id_comanda'].any((campo) =>
            dados[campo] != '0' && dados[campo] == anterior[campo])) {
          throw StateError('Esta mesa ou comanda ja tem uma abertura salva no aparelho.');
        }
      }
      await tx.insert('operacoes', {
        'id': operacao, 'escopo': escopo, 'atendimento': id,
        'acao': 'abertura', 'estado': 'pendente', 'dados': jsonEncode(dados),
        'impressoes': '[]', 'destino': destino,
        'criado': DateTime.now().millisecondsSinceEpoch,
      });
    });
    return id;
  }

  Future<Map<String, dynamic>> detalhe(String id) async {
    final op = await abertura(id);
    if (op == null) throw StateError('Atendimento local nao encontrado nesta conta.');
    final base = Map<String, dynamic>.from(dados(op)['detalhe'] as Map);
    final resposta = recibo(op);
    final itens = <dynamic>[];
    for (final pedido in await banco.db.query('operacoes',
        where: "escopo = ? AND atendimento = ? AND acao = 'produtos' AND estado <> 'arquivado'",
        whereArgs: [escopo, id])) {
      itens.addAll(dados(pedido)['produtos'] as List? ?? []);
    }
    final total = itens.fold<double>(0, (soma, item) => soma +
        (double.tryParse(item['valorVenda'].toString()) ?? 0) *
        (double.tryParse(item['quantidade'].toString()) ?? 0));
    return {...base, 'id': id, 'produtos': itens,
      'status': ['conflito', 'arquivado'].contains(op['estado']) ? 'Fechamento' : 'Andamento',
      'numeroPedido': resposta['numeroPedido']?.toString() ?? '',
      'valorTotal': total.toStringAsFixed(2)};
  }

  Future<List<dynamic>> projetarLista(List<dynamic> grupos, String tipo, String pesquisa) async {
    final campo = tipo == 'mesa' ? 'mesas' : 'comandas';
    final ocupado = tipo == 'mesa' ? 'mesaOcupada' : 'comandaOcupada';
    final copia = List<Map<String, dynamic>>.from(jsonDecode(jsonEncode(grupos)) as List);
    final aberturas = await banco.db.query('operacoes',
        where: "escopo = ? AND acao = 'abertura' AND estado NOT IN ('conflito', 'arquivado')",
        whereArgs: [escopo]);
    for (final op in aberturas) {
      final d = dados(op);
      if (d['tipo'] != tipo) continue;
      final id = d['id_$tipo'];
      final resposta = recibo(op);
      final real = resposta['id_comanda_pedido'];
      final localId = op['atendimento'] as String;
      if (real != null) {
        for (final grupo in copia) {
          for (final recurso in grupo[campo] as List? ?? []) {
            if (recurso['idComandaPedido'] == real) recurso['idComandaPedido'] = localId;
          }
        }
        continue;
      }
      final detalhe = await this.detalhe(localId);
      if (pesquisa.isNotEmpty && !['nome', 'nomeCliente', 'codigo', 'observacaoDoPedido']
          .any((c) => (detalhe[c] ?? '').toString().toLowerCase().contains(pesquisa.toLowerCase()))) {
        continue;
      }
      // Nao esconde outro atendimento ja recebido do servidor.
      if (copia.any((g) => (g[campo] as List? ?? []).any((r) =>
          r['id'] == id && r[ocupado] == true))) {
        continue;
      }
      for (final grupo in copia) {
        (grupo[campo] as List?)?.removeWhere((r) => r['id'] == id);
      }
      var grupo = copia.where((g) => g['titulo'] == 'Ocupadas').firstOrNull;
      if (grupo == null) {
        grupo = {'titulo': 'Ocupadas', campo: <dynamic>[]};
        copia.insert(0, grupo);
      }
      (grupo[campo] as List).add({
        'id': id, 'nome': detalhe['nome'], 'codigo': detalhe['codigo'], 'ativo': 'Sim',
        ocupado: true, 'idComandaPedido': localId, 'idCliente': detalhe['idCliente'],
        'nomeCliente': detalhe['nomeCliente'], 'obs': detalhe['observacaoDoPedido'],
        'nomeMesa': detalhe['nomeMesa'], 'idmesa': detalhe['idMesa'],
        'dataAbertura': detalhe['dataAbertura'], 'horaAbertura': '',
        'dataultimopedido': '', 'valor': detalhe['valorTotal'], 'fechamento': false,
      });
    }
    return copia;
  }

  Future<String> nomeCliente(String id) async {
    final chave = CacheConsultas.chave(RequestOptions(path: 'comandas/listar_clientes.php',
        queryParameters: {'empresa': (jsonDecode(escopo) as List)[1], 'pesquisa': ''}));
    final consulta = await banco.consulta(escopo, chave);
    if (consulta == null) return '';
    final clientes = jsonDecode(consulta['valor'] as String) as List;
    final cliente = clientes.whereType<Map>().where((c) => c['id'].toString() == id).firstOrNull;
    return (cliente?['nome'] ?? cliente?['razao_social'] ?? '').toString();
  }
}
