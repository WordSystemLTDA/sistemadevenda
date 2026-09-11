import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:flutter/material.dart';

class PendenciasImpressao extends StatelessWidget {
  const PendenciasImpressao(
      {super.key, required this.fila, required this.reenviar});

  final FilaImpressao fila;
  final Future<void> Function(String id) reenviar;

  Future<void> _confirmar(
      BuildContext context, ImpressaoPendente item, bool reimprimir) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
            reimprimir ? 'Reenviar comprovante?' : 'Confirmar recebimento?'),
        content: Text(reimprimir
            ? 'Confira antes com a cozinha. Se o comprovante ja chegou, reenviar pode gerar uma via duplicada. O pedido nao sera lancado novamente.'
            : 'A cozinha recebeu este comprovante? A pendencia sera encerrada sem reenviar o pedido.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(reimprimir ? 'Reenviar' : 'Recebido')),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      if (reimprimir) {
        await reenviar(item.id);
      } else {
        await fila.confirmar(item.id);
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Nao foi possivel atualizar a impressao. A pendencia foi mantida.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Impressões pendentes')),
        body: ListenableBuilder(
          listenable: fila,
          builder: (context, _) => fila.itens.isEmpty
              ? const Center(child: Text('Nenhuma impressão pendente'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: fila.itens.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final item = fila.itens[index];
                    final dados = item.dados;
                    final produtos = (dados['produtos'] as List?) ?? [];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${dados['comanda'] ?? dados['tipo'] ?? 'Pedido'} - #${dados['numeroPedido'] ?? dados['id'] ?? ''}',
                            style: Theme.of(context).textTheme.titleMedium),
                        if ((dados['nomedopc'] ?? '').toString().isNotEmpty)
                          Text(dados['nomedopc'].toString()),
                        if (item.servidor.isNotEmpty) Text(item.servidor),
                        for (final produto in produtos)
                          Text(
                              '${produto['quantidade'] ?? 1}x ${produto['nome'] ?? ''}'),
                        const SizedBox(height: 8),
                        Text(
                            switch (item.estado) {
                              EstadoImpressao.aguardandoPedido =>
                                'Registro do pedido sem confirmacao. Confira o atendimento antes de imprimir.',
                              EstadoImpressao.aguardandoEnvio =>
                                'Aguardando envio automatico',
                              EstadoImpressao.semConfirmacao =>
                                'Aguardando confirmacao. Recuperacao automatica em andamento.',
                              EstadoImpressao.erro =>
                                item.erro ?? 'Falha informada pelo servidor',
                            },
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          overflowAlignment: OverflowBarAlignment.end,
                          children: [
                            if (dados['protocoloImpressao'] != 2)
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmar(context, item, false),
                                icon: const Icon(Icons.check),
                                label: const Text('Recebido na cozinha'),
                              ),
                            if (item.estado != EstadoImpressao.aguardandoEnvio)
                              TextButton.icon(
                                onPressed: () =>
                                    _confirmar(context, item, true),
                                icon: const Icon(Icons.print_outlined),
                                label: const Text('Reenviar'),
                              ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
        ),
      );
}
