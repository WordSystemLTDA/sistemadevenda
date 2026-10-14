import 'dart:convert';

import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:crypto/crypto.dart';

/// Cancelar a operacao nao altera nem estorna o pagamento do cliente.
/// O mesmo ID permanece duravel ate o servidor confirmar o cancelamento.
class CancelamentosDeliveryOffline {
  final BancoLocal banco;
  final String escopo;
  CancelamentosDeliveryOffline(this.banco, this.escopo);

  Future<Map<String, Object?>?> operacao(String id) async =>
      (await banco.db.query('operacoes',
              where: 'escopo = ? AND id = ? AND acao = ?',
              whereArgs: [escopo, id, 'cancelar_delivery'],
              limit: 1))
          .firstOrNull;

  Future<Set<String>> pedidosOcultos() async => {
        for (final op in await banco.db.query('operacoes',
            columns: ['atendimento'],
            where: "escopo = ? AND acao = 'cancelar_delivery' "
                "AND estado NOT IN ('conflito', 'arquivado')",
            whereArgs: [escopo]))
          op['atendimento'] as String,
      };

  static bool afetaOperacao(Map<String, Object?> op, Set<String> cancelados) {
    if (cancelados.contains(op['atendimento'])) return true;
    if (op['acao'] != 'delivery') return false;
    final recibo = jsonDecode(op['resposta'] as String? ?? '{}') as Map;
    return cancelados.contains(recibo['idDelivery']?.toString());
  }

  Future<String> guardar({
    required String id,
    required String empresa,
    required String usuario,
    required String senha,
    required String motivo,
    required String etapa,
    required String destino,
  }) async {
    if (escopo.isEmpty || (int.tryParse(id) ?? 0) <= 0) {
      throw StateError('Pedido invalido para cancelamento.');
    }
    if (senha.trim().isEmpty) {
      throw StateError('Informe a senha Admin.');
    }
    return banco.db.transaction((tx) async {
      final anterior = (await tx.query('operacoes',
              where: "escopo = ? AND atendimento = ? "
                  "AND acao = 'cancelar_delivery' "
                  "AND estado NOT IN ('conflito', 'arquivado')",
              whereArgs: [escopo, id],
              limit: 1))
          .firstOrNull;
      if (anterior != null) return anterior['id'] as String;
      final operacao = BancoLocal.novoId();
      final autorizacao = Hmac(sha256, utf8.encode(senha.trim()))
          .convert(utf8.encode(jsonEncode([
            'cancelar_delivery',
            operacao,
            empresa,
            usuario,
            id,
          ])))
          .toString();
      await tx.insert('operacoes', {
        'id': operacao,
        'escopo': escopo,
        'atendimento': id,
        'acao': 'cancelar_delivery',
        'estado': 'pendente',
        'dados': jsonEncode({
          'empresa': empresa,
          'id_usuario': usuario,
          'id': id,
          'autorizacao_cancelamento': autorizacao,
          'motivo': motivo.trim(),
          'statusOrigem': etapa,
        }),
        'impressoes': '[]',
        'destino': destino,
        'criado': DateTime.now().millisecondsSinceEpoch,
      });
      return operacao;
    });
  }
}
