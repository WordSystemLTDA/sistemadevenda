import 'dart:convert';

import 'package:flutter/material.dart';
import 'sincronizador.dart';

class EstadoSincronizacao extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  const EstadoSincronizacao({super.key, this.navigatorKey});

  @override
  Widget build(BuildContext context) {
    final sync = Sincronizador.instancia;
    if (sync == null) return const SizedBox.shrink();
    return ListenableBuilder(listenable: sync, builder: (context, _) {
      if (sync.escopo.isEmpty) return const SizedBox.shrink();
      final cs = Theme.of(context).colorScheme;
      final atencao = sync.conflitos > 0 || sync.erro != null;
      final texto = sync.conflitos > 0
          ? '${sync.conflitos} pedido(s) para conferir'
          : sync.pendencias.isNotEmpty
              ? '${sync.pendencias.length} pedido(s) aguardando envio'
              : sync.erro != null ? 'Verificar sincronizacao'
              : !sync.online ? 'Sem conexao com o servidor'
              : !sync.catalogoPronto ? 'Preparando cardapio no aparelho'
              : 'Pedidos sincronizados';
      return Material(
        color: atencao ? cs.errorContainer : cs.surfaceContainerLow,
        child: InkWell(
          onTap: () => navigatorKey?.currentState?.push(MaterialPageRoute<void>(
              builder: (_) => PendenciasSincronizacao(sincronizador: sync))),
          child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Icon(atencao ? Icons.error_outline : sync.online
                  ? Icons.cloud_done_outlined : Icons.cloud_off_outlined, size: 19),
              const SizedBox(width: 8),
              Expanded(child: Text(texto, style: const TextStyle(fontSize: 12))),
              const Icon(Icons.chevron_right, size: 18),
            ])),
        ),
      );
    });
  }
}

class PendenciasSincronizacao extends StatelessWidget {
  final Sincronizador sincronizador;
  const PendenciasSincronizacao({super.key, required this.sincronizador});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: sincronizador,
    builder: (context, _) {
      final cs = Theme.of(context).colorScheme;
      return Scaffold(
        appBar: AppBar(title: const Text('Envio dos pedidos'), actions: [
          IconButton(tooltip: 'Sincronizar agora', onPressed: sincronizador.sincronizando
              ? null : sincronizador.tentarNovamente, icon: const Icon(Icons.sync)),
        ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (sincronizador.erro != null)
            Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Text(sincronizador.erro!, style: TextStyle(color: cs.error))),
          if (sincronizador.pendencias.isEmpty)
            const ListTile(leading: Icon(Icons.cloud_done_outlined),
                title: Text('Nenhum pedido aguardando envio')),
          for (final op in sincronizador.pendencias) _pedido(context, op),
        ]),
      );
    },
  );

  Widget _pedido(BuildContext context, Map<String, Object?> op) {
    final dados = jsonDecode(op['dados'] as String) as Map<String, dynamic>;
    final mensagens = jsonDecode(op['impressoes'] as String) as List;
    final comprovante = mensagens.isEmpty ? <String, dynamic>{} :
        jsonDecode(mensagens.first as String) as Map<String, dynamic>;
    final conflito = op['estado'] == 'conflito';
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: conflito ? cs.errorContainer : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(padding: const EdgeInsets.all(12), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(comprovante['comanda']?.toString() ?? 'Atendimento ${op['atendimento']}',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(conflito ? (op['erro']?.toString() ?? 'Confira este pedido com o responsavel.')
              : 'Salvo no aparelho. Aguardando confirmacao do servidor.'),
          const Divider(),
          for (final item in (dados['produtos'] as List? ?? [])) ...[
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(item['nome']?.toString() ?? 'Produto')),
              const SizedBox(width: 12),
              Text('${item['quantidade']}x'),
            ]),
            if ((item['observacao'] ?? '').toString().isNotEmpty)
              Text(item['observacao'].toString()),
            const SizedBox(height: 8),
          ],
        ],
      )),
    );
  }
}
