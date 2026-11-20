import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:flutter/material.dart';

class PendenciasImpressao extends StatefulWidget {
  const PendenciasImpressao(
      {super.key,
      required this.fila,
      required this.reenviar,
      this.limpar,
      this.pertenceAoEscopo,
      this.conexao,
      this.conectado,
      this.mensagemConexao});

  final FilaImpressao fila;
  final Future<void> Function(String id) reenviar;
  final Future<void> Function(List<String> ids)? limpar;
  final bool Function(ImpressaoPendente)? pertenceAoEscopo;
  final Listenable? conexao;
  final bool Function()? conectado;
  final String? Function()? mensagemConexao;

  @override
  State<PendenciasImpressao> createState() => _PendenciasImpressaoState();
}

class _PendenciasImpressaoState extends State<PendenciasImpressao> {
  final _confirmacoesAbertas = <String>{};
  final _reenviosEmAndamento = <String>{};
  FilaImpressao get fila => widget.fila;

  List<ImpressaoPendente> get _itens => fila.itens
      .where((item) => widget.pertenceAoEscopo?.call(item) ?? true)
      .toList();

  Future<void> _limpar(BuildContext context) async {
    final ids = _itens
        .where((item) =>
            item.estado != EstadoImpressao.aguardandoPedido &&
            item.estado != EstadoImpressao.cancelamentoPendente)
        .map((item) => item.id)
        .toList();
    if (ids.isEmpty) return;
    final confirmou = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('Limpar impressões?'),
              content: Text(
                  'Cancelar ${ids.length} impressão(ões) pendente(s)? Os pedidos serão mantidos. Se estiver sem conexão, o cancelamento será enviado ao reconectar. Uma via já enviada à impressora ainda pode sair.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Limpar')),
              ],
            ));
    if (confirmou != true) return;
    try {
      await widget.limpar!(ids);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível limpar todas as impressões. Confira as pendências.')));
      }
    }
  }

  static List<Map<String, dynamic>> _produtos(Object? valor) {
    if (valor is! List) return const [];
    return [
      for (final produto in valor)
        if (produto is Map)
          {
            for (final entrada in produto.entries)
              if (entrada.key != null) entrada.key.toString(): entrada.value,
          }
    ];
  }

  Future<void> _confirmar(
      BuildContext context, ImpressaoPendente item, bool reimprimir) async {
    if (_reenviosEmAndamento.contains(item.id) ||
        !_confirmacoesAbertas.add(item.id)) {
      return;
    }
    var respondeu = false;
    void responder(BuildContext context, bool resposta) {
      if (respondeu) return;
      respondeu = true;
      Navigator.pop(context, resposta);
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
            reimprimir ? 'Reenviar comprovante?' : 'Confirmar recebimento?'),
        content: Text(reimprimir
            ? 'Confira se este comprovante já foi impresso. Reenviar pode gerar uma via duplicada. Será reenviada somente esta impressão; o pedido não será lançado novamente.'
            : 'A cozinha recebeu este comprovante? A pendencia sera encerrada sem reenviar o pedido.'),
        actions: [
          TextButton(
              onPressed: () => responder(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => responder(context, true),
              child: Text(reimprimir ? 'Reenviar' : 'Recebido')),
        ],
      ),
    );
    _confirmacoesAbertas.remove(item.id);
    if (confirmou != true || !mounted) return;
    setState(() => _reenviosEmAndamento.add(item.id));
    try {
      if (reimprimir) {
        await widget.reenviar(item.id);
      } else {
        await fila.confirmar(item.id);
      }
    } catch (erro) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(erro is StateError
                ? erro.message.toString()
                : 'Não foi possível atualizar a impressão. A pendência foi mantida.')));
      }
    } finally {
      if (mounted) setState(() => _reenviosEmAndamento.remove(item.id));
    }
  }

  Future<void> _excluir(BuildContext context, ImpressaoPendente item) async {
    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Excluir pendência?'),
        content: const Text(
            'Use esta opção se o comprovante já foi impresso ou não deve mais ser enviado. O pedido será mantido. Uma impressão que já chegou ao servidor ainda poderá sair.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton.icon(
              style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError),
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Excluir')),
        ],
      ),
    );
    if (confirmou != true) return;
    try {
      await fila.confirmar(item.id, cancelada: true);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível excluir a pendência. Tente novamente.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Impressões pendentes'), actions: [
          if (widget.limpar != null)
            IconButton(
                tooltip: 'Limpar pendências',
                onPressed: _reenviosEmAndamento.isNotEmpty
                    ? null
                    : () => _limpar(context),
                icon: const Icon(Icons.clear_all)),
        ]),
        body: ListenableBuilder(
          listenable: Listenable.merge([fila, widget.conexao]),
          builder: (context, _) => _itens.isEmpty
              ? const Center(child: Text('Nenhuma impressão pendente'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _itens.length,
                  separatorBuilder: (_, __) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final item = _itens[index];
                    final dados = item.dados;
                    final produtos = _produtos(dados['produtos']);
                    final reenviando = _reenviosEmAndamento.contains(item.id);
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
                              EstadoImpressao.aguardandoEnvio => widget
                                          .conectado
                                          ?.call() ==
                                      false
                                  ? '${widget.mensagemConexao?.call() ?? 'Sem conexão com o servidor.'} Impressão salva para reenvio.'
                                  : 'Impressão salva. Aguardando envio ao servidor.',
                              EstadoImpressao.semConfirmacao =>
                                'Enviada ao servidor. Aguardando confirmação da impressão.',
                              EstadoImpressao.erro =>
                                item.erro ?? 'Falha informada pelo servidor',
                              EstadoImpressao.pausada => item.erro ??
                                  'Impressão pausada. Confira a cozinha.',
                              EstadoImpressao.cancelamentoPendente =>
                                'Cancelamento aguardando confirmação do servidor. O pedido foi mantido.',
                            },
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        OverflowBar(
                          alignment: MainAxisAlignment.end,
                          overflowAlignment: OverflowBarAlignment.end,
                          children: [
                            if (item.estado != EstadoImpressao.aguardandoPedido)
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                    foregroundColor:
                                        Theme.of(context).colorScheme.error),
                                onPressed: reenviando
                                    ? null
                                    : () => _excluir(context, item),
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Excluir'),
                              ),
                            if (dados['protocoloImpressao'] != 2 &&
                                item.estado !=
                                    EstadoImpressao.cancelamentoPendente)
                              TextButton.icon(
                                onPressed: reenviando
                                    ? null
                                    : () => _confirmar(context, item, false),
                                icon: const Icon(Icons.check),
                                label: const Text('Recebido na cozinha'),
                              ),
                            if (item.estado !=
                                    EstadoImpressao.aguardandoPedido &&
                                item.estado !=
                                    EstadoImpressao.cancelamentoPendente)
                              TextButton.icon(
                                onPressed: reenviando
                                    ? null
                                    : () => _confirmar(context, item, true),
                                icon: const Icon(Icons.print_outlined),
                                label: Text(
                                    reenviando ? 'Reenviando…' : 'Reenviar'),
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
