import 'dart:convert';

import '../api/socket/canal_atualizacao_online.dart';
import '../api/socket/fila_impressao.dart';

/// Exibe os comprovantes que ainda pertencem ao pedido durável. Não os insere
/// na fila de envio: só o recibo da API pode liberar a impressão.
List<ImpressaoPendente> impressoesAguardandoPedido(
  Iterable<Map<String, Object?>> operacoes, {
  required String empresa,
  String? escopoOnline,
}) {
  if (empresa.isEmpty) return const [];
  final itens = <String, ImpressaoPendente>{};
  for (final operacao in operacoes) {
    if (!const {'pendente', 'registrado', 'conflito'}
        .contains(operacao['estado'])) {
      continue;
    }
    try {
      final mensagens = operacao['impressoes'] is String
          ? jsonDecode(operacao['impressoes'] as String)
          : operacao['impressoes'];
      if (mensagens is! List) continue;
      for (final mensagem in mensagens) {
        try {
          final item = ImpressaoPendente(
              mensagem is String ? mensagem : jsonEncode(mensagem));
          final dados = item.dados;
          final empresaItem = '${dados['idEmpresa'] ?? ''}';
          final escopoItem = dados[CanalAtualizacaoOnline.chaveEscopo];
          if (item.id.isEmpty ||
              dados['tipoImpressao'] == null ||
              (empresaItem.isNotEmpty && empresaItem != empresa) ||
              (escopoItem != null && escopoItem != escopoOnline)) {
            continue;
          }
          itens.putIfAbsent(
              item.id,
              () => ImpressaoPendente(
                    jsonEncode({
                      ...dados,
                      if (empresaItem.isEmpty) 'idEmpresa': empresa,
                      if (escopoOnline != null)
                        CanalAtualizacaoOnline.chaveEscopo: escopoOnline,
                    }),
                    estado: EstadoImpressao.aguardandoPedido,
                    servidor: '${operacao['destino'] ?? ''}',
                    erro: operacao['estado'] == 'conflito'
                        ? 'O pedido precisa de conferência antes de imprimir. '
                                '${operacao['erro'] ?? ''}'
                            .trim()
                        : null,
                  ));
        } catch (_) {
          // Um comprovante antigo incompleto não esconde os demais.
        }
      }
    } catch (_) {
      // A operação original permanece no banco para recuperação.
    }
  }
  return List.unmodifiable(itens.values);
}
