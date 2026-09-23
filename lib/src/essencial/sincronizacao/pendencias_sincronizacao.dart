import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'package:intl/intl.dart';
import 'sincronizador.dart';
import 'seguranca_pendencias.dart';

class EstadoSincronizacao extends StatelessWidget {
  static const double espacoNoCabecalho = 52;
  static const double recuoDireitaCabecalho = 8;

  final GlobalKey<NavigatorState>? navigatorKey;
  final bool flutuante;
  const EstadoSincronizacao(
      {super.key, this.navigatorKey, this.flutuante = false});

  @override
  Widget build(BuildContext context) {
    final sync = Sincronizador.instancia;
    if (sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
        listenable: Listenable.merge([sync, sync.socket]),
        builder: (context, _) {
          if (sync.escopo.isEmpty) return const SizedBox.shrink();
          final cs = Theme.of(context).colorScheme;
          final atencao = sync.conflitos > 0 || sync.erro != null;
          final impressoes = sync.impressoesPendentes;
          final texto = sync.conflitos > 0
              ? '${sync.conflitos} pedido(s) para conferir'
              : sync.pendencias.isNotEmpty
                  ? '${sync.pendencias.length} pedido(s) aguardando envio'
                  : impressoes > 0
                      ? '$impressoes impressao(oes) aguardando confirmacao'
                      : sync.erro != null
                          ? 'Verificar sincronizacao'
                          : !sync.online
                              ? 'Sem conexao com o servidor'
                              : !sync.socket.connected
                                  ? 'Canal da cozinha desconectado'
                                  : sync.sincronizando
                                      ? 'Sincronizando pedidos e dados'
                                      : !sync.catalogoPronto
                                          ? 'Preparando cardapio no aparelho'
                                          : 'Pedidos sincronizados';
          final icon = atencao
              ? Icons.error_outline
              : !sync.online
                  ? Icons.cloud_off_outlined
                  : !sync.socket.connected
                      ? Icons.print_disabled_outlined
                      : impressoes > 0
                          ? Icons.print_outlined
                          : sync.sincronizando || sync.pendencias.isNotEmpty
                              ? Icons.sync
                              : Icons.cloud_done_outlined;
          final quantidadeAvisos = sync.conflitos > 0
              ? sync.conflitos
              : sync.pendencias.isNotEmpty
                  ? sync.pendencias.length
                  : impressoes;
          void abrirPendencias() => navigatorKey?.currentState?.push(
                MaterialPageRoute<void>(
                  builder: (_) => PendenciasSincronizacao(sincronizador: sync),
                ),
              );
          if (flutuante) {
            final corFundo = atencao
                ? cs.errorContainer.withValues(alpha: 0.95)
                : cs.surface.withValues(alpha: 0.58);
            final corIcone = atencao ? cs.onErrorContainer : cs.onSurface;
            return Tooltip(
              message: texto,
              child: Opacity(
                opacity: atencao || quantidadeAvisos > 0 ? 1 : 0.58,
                child: Stack(clipBehavior: Clip.none, children: [
                  Material(
                    color: corFundo,
                    elevation: atencao ? 4 : 1,
                    shadowColor: cs.shadow.withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: atencao
                            ? cs.error.withValues(alpha: 0.45)
                            : cs.outlineVariant.withValues(alpha: 0.35),
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: abrirPendencias,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(icon, size: 22, color: corIcone),
                      ),
                    ),
                  ),
                  if (quantidadeAvisos > 0)
                    Positioned(
                      top: -5,
                      right: -5,
                      child: Container(
                        constraints:
                            const BoxConstraints(minWidth: 18, minHeight: 18),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          color: atencao ? cs.error : cs.primary,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          quantidadeAvisos > 9 ? '9+' : '$quantidadeAvisos',
                          style: TextStyle(
                            color: atencao ? cs.onError : cs.onPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            );
          }
          return Material(
            color: atencao ? cs.errorContainer : cs.surfaceContainerLow,
            child: InkWell(
              onTap: abrirPendencias,
              child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(children: [
                    Icon(icon, size: 19),
                    const SizedBox(width: 8),
                    Expanded(
                        child:
                            Text(texto, style: const TextStyle(fontSize: 12))),
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

  static Map<String, dynamic> _mapa(Object? valor) {
    if (valor is Map) {
      return {
        for (final entrada in valor.entries)
          if (entrada.key != null) entrada.key.toString(): entrada.value,
      };
    }
    if (valor is String && valor.trim().isNotEmpty) {
      try {
        final decodificado = jsonDecode(valor);
        if (decodificado is Map) return _mapa(decodificado);
      } catch (_) {
        return const {};
      }
    }
    return const {};
  }

  static List<Object?> _lista(Object? valor) {
    if (valor is List) return valor;
    if (valor is String && valor.trim().isNotEmpty) {
      try {
        final decodificado = jsonDecode(valor);
        if (decodificado is List) return decodificado;
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([sincronizador, sincronizador.socket]),
        builder: (context, _) {
          final cs = Theme.of(context).colorScheme;
          return Scaffold(
            appBar: AppBar(title: const Text('Envio dos pedidos'), actions: [
              IconButton(
                  tooltip: 'Sincronizar agora',
                  onPressed: sincronizador.sincronizando
                      ? null
                      : sincronizador.tentarNovamente,
                  icon: const Icon(Icons.sync)),
            ]),
            body: ListView(padding: const EdgeInsets.all(16), children: [
              if (sincronizador.erro != null)
                Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(sincronizador.erro!,
                        style: TextStyle(color: cs.error))),
              if (sincronizador.conflitos > 0)
                Card(
                  color: cs.errorContainer,
                  child: const ListTile(
                    leading: Icon(Icons.warning_amber_rounded),
                    title: Text('Existem pedidos que precisam de conferencia'),
                    subtitle: Text(
                        'Pedidos recusados nao serao enviados automaticamente. '
                        'Confira antes de excluir da sincronizacao. '
                        'Os demais atendimentos continuam sendo enviados.'),
                  ),
                ),
              for (final op in sincronizador.pendencias) _pedido(context, op),
              ListTile(
                leading: Icon(sincronizador.online
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_off_outlined),
                title: const Text('Servidor de dados'),
                subtitle: Text(sincronizador.online
                    ? (sincronizador.sincronizando
                        ? 'Atualizando dados'
                        : 'Conectado')
                    : 'Sem conexao'),
              ),
              ListTile(
                leading: Icon(sincronizador.socket.connected
                    ? Icons.print_outlined
                    : Icons.print_disabled_outlined),
                title: const Text('Canal da cozinha'),
                subtitle: Text(sincronizador.socket.connected
                    ? 'Conectado'
                    : 'Aguardando reconexao'),
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu),
                title: const Text('Cardapio offline'),
                subtitle: Text(sincronizador.catalogoPronto
                    ? 'Disponivel no aparelho'
                    : 'Primeira sincronizacao pendente'),
              ),
              if (sincronizador.ultimaAtualizacao != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Ultima atualizacao: ${DateFormat('dd/MM HH:mm').format(sincronizador.ultimaAtualizacao!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const Divider(),
              if (sincronizador.pendencias.isEmpty)
                const ListTile(
                    leading: Icon(Icons.cloud_done_outlined),
                    title: Text('Nenhum pedido aguardando envio')),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Conferir impressoes'),
                subtitle: Text(sincronizador.impressoesPendentes == 0
                    ? 'Nenhuma confirmacao pendente'
                    : '${sincronizador.impressoesPendentes} aguardando confirmacao'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PendenciasImpressao(
                          fila: sincronizador.socket.filaImpressao,
                          reenviar: (id) async {
                            await sincronizador.socket.filaImpressao
                                .autorizarReenvio(id);
                            await sincronizador.socket
                                .processarImpressoesPendentes();
                          },
                        ))),
              ),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: sincronizador.rascunhosBloqueados(),
                builder: (context, snapshot) => Column(children: [
                  for (final rascunho
                      in snapshot.data ?? <Map<String, dynamic>>[])
                    _pedido(context, {
                      'atendimento': rascunho['idAtendimento'],
                      'estado': 'rascunho',
                      'rascunho': rascunho,
                      'impressoes': '[]',
                      'erro':
                          'Rascunho preservado. O atendimento foi fechado ou bloqueado no servidor.',
                      'dados': jsonEncode({
                        'produtos': [
                          ...rascunho['itens'] as List? ?? [],
                          ...rascunho['recorrentes'] as List? ?? [],
                        ]
                      }),
                    }),
                ]),
              ),
            ]),
          );
        },
      );

  Widget _pedido(BuildContext context, Map<String, Object?> op) {
    final dados = _mapa(op['dados']);
    final mensagens = _lista(op['impressoes']);
    final comprovante =
        mensagens.map(_mapa).firstWhere((m) => m.isNotEmpty, orElse: () => {});
    final conflito = op['estado'] == 'conflito';
    final rascunho = op['estado'] == 'rascunho';
    final cs = Theme.of(context).colorScheme;
    final produtos = _lista(dados['produtos'])
        .map(_mapa)
        .where((item) => item.isNotEmpty)
        .toList();
    final idOperacao = op['id']?.toString() ?? '';
    final erroOperacao = (op['erro'] ?? '').toString().trim().isNotEmpty;
    final definitivo = SegurancaPendencias.conflitoDefinitivo(op);
    final podeReenviar = idOperacao.isNotEmpty &&
        !rascunho &&
        !definitivo &&
        (conflito || erroOperacao);
    final podeVoltarCarrinho = idOperacao.isNotEmpty &&
        !rascunho &&
        produtos.isNotEmpty &&
        SegurancaPendencias.podeRecuperar(op);
    final podeArquivar = conflito && idOperacao.isNotEmpty || rascunho;
    return Card(
      color: conflito || rascunho ? cs.errorContainer : cs.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  comprovante['comanda']?.toString() ??
                      (dados['detalhe'] is Map
                          ? 'Abertura: ${dados['detalhe']['nome']}'
                          : null) ??
                      'Atendimento ${op['atendimento']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(conflito || rascunho
                  ? (op['erro']?.toString() ??
                      'Confira este pedido com o responsavel.')
                  : 'Salvo no aparelho. Aguardando confirmacao do servidor.'),
              if (definitivo)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Envio bloqueado: este pedido nao pode ser aplicado ao atendimento atual. '
                      'Nenhum novo atendimento sera aberto automaticamente para recebe-lo.'),
                ),
              const Divider(),
              if (op['acao'] == 'abertura') ...[
                Text('Cliente: ${dados['detalhe']?['nomeCliente'] ?? ''}'),
                if ((dados['obs'] ?? '').toString().isNotEmpty)
                  Text(dados['obs'].toString()),
              ],
              if (produtos.isEmpty && op['acao'] != 'abertura')
                Text(
                  'Nao foi possivel detalhar os itens salvos neste registro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final item in produtos) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(item['nome']?.toString() ?? 'Produto')),
                  const SizedBox(width: 12),
                  Text('${item['quantidade']}x'),
                ]),
                if ((item['observacao'] ?? '').toString().isNotEmpty)
                  Text(item['observacao'].toString()),
                for (final opcao
                    in _lista(item['opcoesPacotesListaFinal']).map(_mapa))
                  if (_lista(opcao['dados']).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${opcao['titulo'] ?? 'Opcoes'}: ${_lista(opcao['dados']).map(_mapa).map((d) => '${d['quantidade'] == null ? '' : '${d['quantidade']}x '}${d['nome'] ?? ''}'.trim()).where((nome) => nome.isNotEmpty).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        )),
                const SizedBox(height: 8),
              ],
              if (podeReenviar || podeVoltarCarrinho || podeArquivar)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 4),
                    if (podeReenviar)
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Reenviar para o Servidor'),
                        onPressed: sincronizador.sincronizando
                            ? null
                            : () async {
                                try {
                                  await sincronizador
                                      .reenviarParaServidor(idOperacao);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Reenvio solicitado. Se o servidor ainda recusar, o pedido continua salvo nesta tela.'),
                                  ));
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Nao foi possivel reenviar agora. O pedido continua salvo no aparelho.'),
                                  ));
                                }
                              },
                      ),
                    if (podeReenviar && podeVoltarCarrinho)
                      const SizedBox(height: 8),
                    if (podeVoltarCarrinho)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 46),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.shopping_cart_checkout_outlined),
                        label: const Text('Voltar esse Pedido para o Carrinho'),
                        onPressed: sincronizador.sincronizando
                            ? null
                            : () async {
                                final confirmado = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                          title: const Text(
                                              'Voltar pedido para o carrinho?'),
                                          content: const Text(
                                              'Os itens salvos voltam para o carrinho para revisar ou editar. Esse registro sai da fila de envio automatico para evitar envio duplicado.'),
                                          actions: [
                                            TextButton(
                                                onPressed: () => Navigator.pop(
                                                    context, false),
                                                child: const Text('Cancelar')),
                                            FilledButton(
                                                onPressed: () => Navigator.pop(
                                                    context, true),
                                                child: const Text(
                                                    'Voltar para o carrinho')),
                                          ],
                                        ));
                                if (confirmado != true) return;
                                try {
                                  await sincronizador
                                      .voltarPedidoParaCarrinho(idOperacao);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Pedido voltou para o carrinho. Revise e envie novamente.'),
                                  ));
                                } catch (_) {
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(const SnackBar(
                                    content: Text(
                                        'Nao foi possivel voltar esse pedido para o carrinho.'),
                                  ));
                                }
                              },
                      ),
                    if ((podeReenviar || podeVoltarCarrinho) && podeArquivar)
                      const SizedBox(height: 4),
                    if (podeArquivar)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.archive_outlined),
                          label: const Text('Excluir da sincronizacao'),
                          onPressed: sincronizador.sincronizando
                              ? null
                              : () async {
                                  final confirmado = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                            title: const Text(
                                                'Excluir esta pendencia?'),
                                            content: const Text(
                                                'Confira os itens com o responsavel antes de continuar. '
                                                'Esta pendencia sai do envio automatico; nao altera pedidos ou pagamentos no servidor. '
                                                'Uma copia fica arquivada neste aparelho para conferencia tecnica.'),
                                            actions: [
                                              TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, false),
                                                  child: const Text('Voltar')),
                                              FilledButton(
                                                  onPressed: () =>
                                                      Navigator.pop(
                                                          context, true),
                                                  child: const Text(
                                                      'Excluir pendencia')),
                                            ],
                                          ));
                                  if (confirmado == true) {
                                    try {
                                      if (rascunho) {
                                        await sincronizador.arquivarRascunho(
                                            _mapa(op['rascunho']));
                                      } else {
                                        await sincronizador
                                            .arquivarConflito(idOperacao);
                                      }
                                    } catch (_) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Nao foi possivel excluir. Os dados continuam salvos.')));
                                    }
                                  }
                                },
                        ),
                      ),
                  ],
                ),
            ],
          )),
    );
  }
}
