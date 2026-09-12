import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/pendencias_impressao.dart';
import 'sincronizador.dart';

class EstadoSincronizacao extends StatelessWidget {
  final GlobalKey<NavigatorState>? navigatorKey;
  final bool flutuante;
  const EstadoSincronizacao(
      {super.key, this.navigatorKey, this.flutuante = false});

  @override
  Widget build(BuildContext context) {
    final sync = Sincronizador.instancia;
    if (sync == null) return const SizedBox.shrink();
    return ListenableBuilder(
        listenable: Listenable.merge([sync, sync.socket.filaImpressao]),
        builder: (context, _) {
          if (sync.escopo.isEmpty) return const SizedBox.shrink();
          final cs = Theme.of(context).colorScheme;
          final atencao = sync.conflitos > 0 || sync.erro != null;
          final impressoes = sync.socket.filaImpressao.itens
              .where((p) =>
                  p.servidor == sync.destino &&
                  p.dados['idEmpresa']?.toString() ==
                      sync.usuario.usuario?.empresa)
              .length;
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
                              : !sync.catalogoPronto
                                  ? 'Preparando cardapio no aparelho'
                                  : 'Pedidos sincronizados';
          final icon = atencao
              ? Icons.error_outline
              : sync.online
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined;
          final quantidadeAvisos = sync.conflitos > 0
              ? sync.conflitos
              : sync.pendencias.isNotEmpty
                  ? sync.pendencias.length
                  : impressoes;
          final abrirPendencias = () => navigatorKey?.currentState?.push(
              MaterialPageRoute<void>(
                  builder: (_) =>
                      PendenciasSincronizacao(sincronizador: sync)));
          if (flutuante) {
            final corFundo = atencao
                ? cs.errorContainer.withOpacity(0.95)
                : cs.surface.withOpacity(0.58);
            final corIcone = atencao ? cs.onErrorContainer : cs.onSurface;
            return Tooltip(
              message: texto,
              child: Opacity(
                opacity: atencao || quantidadeAvisos > 0 ? 1 : 0.58,
                child: Stack(clipBehavior: Clip.none, children: [
                  Material(
                    color: corFundo,
                    elevation: atencao ? 4 : 1,
                    shadowColor: cs.shadow.withOpacity(0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: atencao
                            ? cs.error.withOpacity(0.45)
                            : cs.outlineVariant.withOpacity(0.35),
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

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: sincronizador,
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
              if (sincronizador.pendencias.isEmpty)
                const ListTile(
                    leading: Icon(Icons.cloud_done_outlined),
                    title: Text('Nenhum pedido aguardando envio')),
              ListTile(
                leading: const Icon(Icons.print_outlined),
                title: const Text('Conferir impressoes'),
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
              for (final op in sincronizador.pendencias) _pedido(context, op),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: sincronizador.rascunhosBloqueados(),
                builder: (context, snapshot) => Column(children: [
                  for (final rascunho
                      in snapshot.data ?? <Map<String, dynamic>>[])
                    _pedido(context, {
                      'atendimento': rascunho['idAtendimento'],
                      'estado': 'rascunho',
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
    final dados = jsonDecode(op['dados'] as String) as Map<String, dynamic>;
    final mensagens = jsonDecode(op['impressoes'] as String) as List;
    final comprovante = mensagens.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(mensagens.first as String) as Map<String, dynamic>;
    final conflito = op['estado'] == 'conflito';
    final rascunho = op['estado'] == 'rascunho';
    final cs = Theme.of(context).colorScheme;
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
                      'Atendimento ${op['atendimento']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(conflito || rascunho
                  ? (op['erro']?.toString() ??
                      'Confira este pedido com o responsavel.')
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
                for (final opcao
                    in (item['opcoesPacotesListaFinal'] as List? ?? []))
                  if ((opcao['dados'] as List? ?? []).isNotEmpty)
                    Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          '${opcao['titulo'] ?? 'Opcoes'}: ${(opcao['dados'] as List).map((d) => '${d['quantidade'] == null ? '' : '${d['quantidade']}x '}${d['nome']}').join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall,
                        )),
                const SizedBox(height: 8),
              ],
              if (conflito)
                TextButton.icon(
                  icon: const Icon(Icons.archive_outlined),
                  label: const Text('Arquivar apos conferir'),
                  onPressed: () async {
                    final confirmado = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                              title: const Text(
                                  'Pedido conferido com o responsavel?'),
                              content: const Text(
                                  'Este pedido nao sera enviado nem impresso. Os dados ficam guardados no aparelho para consulta tecnica. Caso necessario, lance um novo pedido no atendimento correto.'),
                              actions: [
                                TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Voltar')),
                                FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Arquivar')),
                              ],
                            ));
                    if (confirmado == true) {
                      await sincronizador.arquivarConflito(op['id'] as String);
                    }
                  },
                ),
            ],
          )),
    );
  }
}
