import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'painel_pendencias.dart';
import 'visual_atendimento.dart';

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
  String _pesquisa = '';
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

  (String, Color) _status(BuildContext context, ImpressaoPendente item) =>
      switch (item.estado) {
        EstadoImpressao.aguardandoPedido => (
            'Conferir pedido',
            corAtencaoPendencias(context)
          ),
        EstadoImpressao.aguardandoEnvio => (
            'Aguardando envio',
            corAtencaoPendencias(context)
          ),
        EstadoImpressao.semConfirmacao => (
            'Aguardando confirmação',
            VisualAtendimento.azul(context)
          ),
        EstadoImpressao.erro => (
            'Falha na impressão',
            Theme.of(context).colorScheme.error
          ),
        EstadoImpressao.pausada => (
            'Impressão pausada',
            corAtencaoPendencias(context)
          ),
        EstadoImpressao.cancelamentoPendente => (
            'Exclusão em andamento',
            VisualAtendimento.azul(context)
          ),
      };

  String _mensagem(ImpressaoPendente item) => switch (item.estado) {
        EstadoImpressao.aguardandoPedido =>
          'Registro do pedido sem confirmação. Confira o atendimento antes de imprimir.',
        EstadoImpressao.aguardandoEnvio => widget.conectado?.call() == false
            ? '${widget.mensagemConexao?.call() ?? 'Sem conexão com o servidor.'} Impressão salva para reenvio.'
            : 'Impressão salva. Aguardando envio ao servidor.',
        EstadoImpressao.semConfirmacao =>
          'Enviada ao servidor. Aguardando confirmação da impressão.',
        EstadoImpressao.erro => item.erro ??
            'O servidor informou uma falha. Confira antes de reenviar.',
        EstadoImpressao.pausada =>
          item.erro ?? 'Impressão pausada. Confira a cozinha.',
        EstadoImpressao.cancelamentoPendente =>
          'Cancelamento aguardando confirmação do servidor. O pedido foi mantido.',
      };

  String _tipo(ImpressaoPendente item) =>
      switch (item.dados['tipoImpressao']?.toString()) {
        '1' => 'Preparo',
        '3' => 'Entregador',
        _ => 'Comprovante',
      };

  String _titulo(ImpressaoPendente item) {
    final dados = item.dados;
    final atendimento = '${dados['comanda'] ?? dados['tipo'] ?? 'Pedido'}';
    final numero = '${dados['numeroPedido'] ?? ''}'.trim();
    return numero.isEmpty ? atendimento : '$atendimento - #$numero';
  }

  Widget _cartao(BuildContext context, ImpressaoPendente item) {
    final cs = Theme.of(context).colorScheme;
    final produtos = _produtos(item.dados['produtos']);
    final reenviando = _reenviosEmAndamento.contains(item.id);
    final (status, cor) = _status(context, item);
    final podeReenviar = item.estado != EstadoImpressao.aguardandoPedido &&
        item.estado != EstadoImpressao.cancelamentoPendente;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: CartaoPainelPendencias(
        key: ValueKey('impressao_${item.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusAtendimento(
                texto: _tipo(item),
                cor: cs.primary,
                icone: item.dados['tipoImpressao']?.toString() == '3'
                    ? Icons.delivery_dining
                    : Icons.receipt_long_outlined,
              ),
              StatusAtendimento(texto: status, cor: cor),
            ]),
            const SizedBox(height: 12),
            Text(_titulo(item),
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontSize: 19, fontWeight: FontWeight.w700)),
            if (produtos.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(10)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final produto in produtos)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                              '${quantidadeConferencia(produto['quantidade'])}x ${produto['nome'] ?? 'Produto'}'),
                        ),
                    ]),
              ),
            ],
            const SizedBox(height: 14),
            AvisoPainelPendencias(texto: _mensagem(item), cor: cor),
            const SizedBox(height: 14),
            if (podeReenviar)
              FilledButton.icon(
                key: ValueKey('reenviar_${item.id}'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                onPressed:
                    reenviando ? null : () => _confirmar(context, item, true),
                icon: Icon(reenviando ? Icons.sync : Icons.print_outlined),
                label: Text(reenviando ? 'Reenviando…' : 'Reenviar'),
              ),
            if (item.dados['protocoloImpressao'] != 2 &&
                item.estado != EstadoImpressao.cancelamentoPendente)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12)),
                  onPressed: reenviando
                      ? null
                      : () => _confirmar(context, item, false),
                  icon: const Icon(Icons.check),
                  label: const Text('Recebido na cozinha'),
                ),
              ),
            if (item.estado != EstadoImpressao.aguardandoPedido)
              TextButton.icon(
                style: TextButton.styleFrom(
                    foregroundColor: cs.error,
                    minimumSize: const Size.fromHeight(48)),
                onPressed: reenviando ? null : () => _excluir(context, item),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Excluir'),
              ),
            const Divider(height: 20),
            ExpansionTile(
              key: PageStorageKey('detalhes_${item.id}'),
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              shape: const Border(),
              collapsedShape: const Border(),
              title: const Text('Detalhes da impressão',
                  style: TextStyle(fontSize: 13)),
              children: [
                _detalhe(context, 'Computador', item.dados['nomedopc']),
                _detalhe(context, 'Servidor', item.servidor),
                _detalhe(context, 'Tentativas de envio', item.tentativas),
                if (item.ultimaTentativa != null)
                  _detalhe(
                      context,
                      'Última tentativa',
                      DateFormat('dd/MM HH:mm')
                          .format(item.ultimaTentativa!.toLocal())),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detalhe(BuildContext context, String rotulo, Object? valor) {
    final texto = '${valor ?? ''}'.trim();
    if (texto.isEmpty) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('$rotulo: $texto',
            style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VisualAtendimento.fundo(context),
        appBar: AppBar(
            title: const Text('Impressões pendentes',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            actions: [
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
          builder: (context, _) {
            final itens = _itens;
            final filtrados = itens.where((item) =>
                '${_titulo(item)} ${_tipo(item)} ${item.dados['produtos']} ${item.dados['nomedopc']}'
                    .toLowerCase()
                    .contains(_pesquisa.trim().toLowerCase()));
            final cs = Theme.of(context).colorScheme;
            return SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      CartaoPainelPendencias(
                        child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              IconePainelPendencias(
                                  icone: itens.isEmpty
                                      ? Icons.task_alt
                                      : Icons.print_outlined,
                                  cor: itens.isEmpty
                                      ? VisualAtendimento.verde(context)
                                      : cs.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        itens.isEmpty
                                            ? 'Nenhuma impressão pendente'
                                            : '${itens.length} ${itens.length == 1 ? 'comprovante para conferir' : 'comprovantes para conferir'}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 6),
                                    Text(
                                        itens.isEmpty
                                            ? 'Não há comprovantes aguardando envio ou confirmação neste aparelho.'
                                            : 'As pendências continuam salvas até a confirmação. Confira se o papel já saiu antes de reenviar.',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                color: cs.onSurfaceVariant,
                                                height: 1.4)),
                                  ],
                                ),
                              ),
                            ]),
                      ),
                      if (itens.length > 3 || _pesquisa.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        TextField(
                          onChanged: (valor) =>
                              setState(() => _pesquisa = valor),
                          decoration: InputDecoration(
                              hintText: 'Buscar pedido ou produto',
                              prefixIcon: const Icon(Icons.search),
                              filled: true,
                              fillColor: VisualAtendimento.superficie(context),
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                      ],
                      if (itens.isNotEmpty)
                        const TituloPainelPendencias('Comprovantes'),
                      if (itens.isNotEmpty && filtrados.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                              'Nenhum comprovante encontrado nesta busca.'),
                        ),
                      for (final item in filtrados) _cartao(context, item),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
}
