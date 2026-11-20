import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/painel_pendencias.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
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

class PendenciasSincronizacao extends StatefulWidget {
  final Sincronizador sincronizador;
  const PendenciasSincronizacao({super.key, required this.sincronizador});

  @override
  State<PendenciasSincronizacao> createState() =>
      _PendenciasSincronizacaoState();
}

class _PendenciasSincronizacaoState extends State<PendenciasSincronizacao> {
  Sincronizador get sincronizador => widget.sincronizador;
  bool _atualizando = false;
  (String, int)? _chaveRascunhos;
  Future<List<Map<String, dynamic>>>? _rascunhos;

  Future<List<Map<String, dynamic>>> _consultarRascunhos() {
    final chave = (sincronizador.escopo, sincronizador.conflitos);
    if (_rascunhos == null || _chaveRascunhos != chave) {
      _chaveRascunhos = chave;
      _rascunhos = sincronizador.rascunhosBloqueados();
    }
    return _rascunhos!;
  }

  Future<void> _atualizar() async {
    if (_atualizando || sincronizador.sincronizando) return;
    setState(() => _atualizando = true);
    try {
      await sincronizador.tentarNovamente();
      if (!mounted) return;
      setState(() => _chaveRascunhos = null);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Verificação concluída. Confira os status abaixo.')));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Não foi possível atualizar agora. Os dados salvos foram mantidos.')));
      }
    } finally {
      if (mounted) setState(() => _atualizando = false);
    }
  }

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
          final impressoes = sincronizador.socket.filaImpressao.itens
              .where(sincronizador.socket.pertenceAEmpresaAtual)
              .length;
          final temPedidos = sincronizador.pendencias.isNotEmpty ||
              sincronizador.conflitos > 0;
          return Scaffold(
            backgroundColor: VisualAtendimento.fundo(context),
            appBar: AppBar(
              title: const Text('Envio dos pedidos',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              actions: [
                IconButton(
                    tooltip: 'Sincronizar agora',
                    onPressed: _ocupado ? null : _atualizar,
                    icon: const Icon(Icons.sync)),
              ],
            ),
            body: SafeArea(
                top: false,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: RefreshIndicator(
                      onRefresh: _atualizar,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        children: [
                          _resumo(context, impressoes),
                          if (sincronizador.erro != null)
                            Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: AvisoPainelPendencias(
                                    texto: sincronizador.erro!,
                                    cor: cs.error,
                                    icone: Icons.error_outline)),
                          if (temPedidos) ...[
                            const TituloPainelPendencias('Pedidos'),
                            if (sincronizador.conflitos > 0)
                              Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: AvisoPainelPendencias(
                                    cor: corAtencaoPendencias(context),
                                    icone: Icons.warning_amber_rounded,
                                    texto:
                                        'Existem pedidos que precisam de conferência. '
                                        'Pedidos recusados não são reenviados automaticamente. '
                                        'Confira os itens abaixo; os demais continuam sendo enviados.',
                                  )),
                            for (final op in sincronizador.pendencias)
                              _pedido(context, op),
                          ],
                          FutureBuilder<List<Map<String, dynamic>>>(
                            future: _consultarRascunhos(),
                            builder: (context, snapshot) => Column(children: [
                              if (snapshot.hasError)
                                const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                        'Não foi possível consultar os rascunhos. Toque em atualizar para tentar novamente.')),
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
                          if (impressoes > 0) ...[
                            const TituloPainelPendencias('Impressões'),
                            _impressoes(context, impressoes),
                          ],
                          const TituloPainelPendencias('Conexões'),
                          _conexoes(context),
                          if (!temPedidos) ...[
                            const TituloPainelPendencias('Pedidos'),
                            CartaoPainelPendencias(
                                child: _estado(context,
                                    icone: Icons.task_alt,
                                    titulo: 'Nenhum pedido aguardando envio',
                                    subtitulo:
                                        'Não há pedidos na fila de envio deste aparelho.',
                                    cor: VisualAtendimento.verde(context))),
                          ],
                          if (impressoes == 0) ...[
                            const TituloPainelPendencias('Impressões'),
                            _impressoes(context, impressoes),
                          ],
                        ],
                      ),
                    ),
                  ),
                )),
          );
        },
      );

  bool get _ocupado => _atualizando || sincronizador.sincronizando;

  Widget _resumo(BuildContext context, int impressoes) {
    final cs = Theme.of(context).colorScheme;
    final pedidos = sincronizador.pendencias.length;
    final precisaConferir =
        pedidos > 0 || impressoes > 0 || sincronizador.conflitos > 0;
    final tudoConectado = sincronizador.online &&
        sincronizador.socket.connected &&
        sincronizador.catalogoPronto &&
        sincronizador.erro == null &&
        !_ocupado;
    return CartaoPainelPendencias(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          IconePainelPendencias(
              icone: precisaConferir
                  ? Icons.receipt_long_outlined
                  : tudoConectado
                      ? Icons.cloud_done_outlined
                      : Icons.sync,
              cor: precisaConferir || !tudoConectado
                  ? cs.primary
                  : VisualAtendimento.verde(context)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  precisaConferir
                      ? 'Há pendências para conferir'
                      : tudoConectado
                          ? 'Envios em dia'
                          : 'Acompanhe os envios',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                  'Veja a conexão e acompanhe os pedidos e comprovantes deste aparelho.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant, height: 1.4)),
            ],
          )),
        ]),
        const SizedBox(height: 16),
        Wrap(spacing: 8, runSpacing: 8, children: [
          StatusAtendimento(
              texto:
                  '$pedidos ${pedidos == 1 ? 'pedido na fila' : 'pedidos na fila'}',
              cor: pedidos > 0
                  ? corAtencaoPendencias(context)
                  : VisualAtendimento.verde(context),
              icone: Icons.cloud_upload_outlined),
          StatusAtendimento(
              texto:
                  '$impressoes ${impressoes == 1 ? 'impressão pendente' : 'impressões pendentes'}',
              cor: impressoes > 0
                  ? corAtencaoPendencias(context)
                  : VisualAtendimento.verde(context),
              icone: Icons.print_outlined),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _ocupado ? null : _atualizar,
          style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.sync),
          label: Text(_ocupado ? 'Verificando…' : 'Atualizar conexão e envios'),
        ),
      ],
    ));
  }

  Widget _impressoes(BuildContext context, int quantidade) =>
      CartaoPainelPendencias(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _estado(context,
              icone: Icons.print_outlined,
              titulo: quantidade == 0
                  ? 'Nenhuma impressão pendente'
                  : '$quantidade ${quantidade == 1 ? 'comprovante para conferir' : 'comprovantes para conferir'}',
              subtitulo: quantidade == 0
                  ? 'Você pode conferir a fila de impressão a qualquer momento.'
                  : 'Confira se o papel já saiu antes de reenviar.',
              cor: quantidade > 0
                  ? corAtencaoPendencias(context)
                  : VisualAtendimento.verde(context)),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () =>
                sincronizador.socket.abrirPendenciasImpressao(context),
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Text('Conferir impressões'),
          ),
        ],
      ));

  Widget _conexoes(BuildContext context) => CartaoPainelPendencias(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _estado(context,
              icone: sincronizador.online
                  ? Icons.cloud_done_outlined
                  : Icons.cloud_off_outlined,
              titulo: 'Servidor de dados',
              subtitulo: sincronizador.online
                  ? (sincronizador.sincronizando
                      ? 'Atualizando dados'
                      : 'Conectado')
                  : 'Sem conexão',
              cor: sincronizador.online
                  ? VisualAtendimento.verde(context)
                  : corAtencaoPendencias(context)),
          const Divider(height: 26),
          _estado(context,
              icone: sincronizador.socket.connected
                  ? Icons.print_outlined
                  : Icons.print_disabled_outlined,
              titulo: 'Canal da cozinha',
              subtitulo: sincronizador.socket.connected
                  ? 'Conectado'
                  : 'Aguardando reconexão',
              cor: sincronizador.socket.connected
                  ? VisualAtendimento.verde(context)
                  : corAtencaoPendencias(context)),
          if (!sincronizador.socket.connected) ...[
            const SizedBox(height: 12),
            AvisoPainelPendencias(
                texto: sincronizador.socket.erroConexao ??
                    'Confira se o computador de impressão está ligado e conectado à mesma rede.',
                cor: corAtencaoPendencias(context)),
          ],
          const Divider(height: 26),
          _estado(context,
              icone: Icons.restaurant_menu,
              titulo: 'Cardápio offline',
              subtitulo: sincronizador.catalogoPronto
                  ? 'Disponível no aparelho'
                  : 'Primeira sincronização pendente',
              cor: sincronizador.catalogoPronto
                  ? VisualAtendimento.verde(context)
                  : corAtencaoPendencias(context)),
          if (sincronizador.ultimaAtualizacao != null) ...[
            const Divider(height: 26),
            Text(
                'Última atualização: ${DateFormat('dd/MM HH:mm').format(sincronizador.ultimaAtualizacao!)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ],
      ));

  Widget _estado(
    BuildContext context, {
    required IconData icone,
    required String titulo,
    required String subtitulo,
    required Color cor,
  }) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        IconePainelPendencias(icone: icone, cor: cor),
        const SizedBox(width: 12),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(subtitulo,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cor, height: 1.35)),
        ])),
      ]);

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
      color: VisualAtendimento.superficie(context),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6))),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusAtendimento(
                  texto: rascunho
                      ? 'Rascunho preservado'
                      : conflito
                          ? 'Precisa de conferência'
                          : 'Aguardando confirmação',
                  cor: conflito || rascunho
                      ? corAtencaoPendencias(context)
                      : VisualAtendimento.azul(context)),
              const SizedBox(height: 10),
              Text(
                  comprovante['comanda']?.toString() ??
                      (dados['detalhe'] is Map
                          ? 'Abertura: ${dados['detalhe']['nome']}'
                          : null) ??
                      (op['acao'] == 'delivery' ? 'Pedido Delivery' : null) ??
                      (op['acao'] == 'cancelar_delivery'
                          ? 'Cancelar Delivery #${op['atendimento']}'
                          : null) ??
                      (op['acao'] == 'recebimento'
                          ? 'Recebimento: ${dados['tipo']} ${dados[dados['tipo'] == 'Mesa' ? 'id_mesa' : 'id_comanda']}'
                          : null) ??
                      'Atendimento ${op['atendimento']}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(conflito || rascunho
                  ? (op['erro']?.toString() ??
                      'Confira este pedido com o responsavel.')
                  : op['recebidoNaRede'] == true
                      ? 'Recebido pelo PC via Wi-Fi. Aguardando internet para confirmar na API.'
                      : 'Salvo no aparelho. Aguardando confirmacao do servidor.'),
              if (!conflito && !rascunho && erroOperacao)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(op['erro'].toString(),
                      style: TextStyle(color: cs.error)),
                ),
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
              if (op['acao'] == 'recebimento')
                Text(
                    'Pagamento: R\$ ${dados['valor_lancamento']} · Troco: R\$ ${dados['valortroco']}'),
              if (produtos.isEmpty &&
                  !['abertura', 'recebimento'].contains(op['acao']))
                Text(
                  'Nao foi possivel detalhar os itens salvos neste registro.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              for (final item in produtos) ...[
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Text(item['nome']?.toString() ?? 'Produto')),
                  const SizedBox(width: 12),
                  Text('${quantidadeConferencia(item['quantidade'])}x'),
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
                                  final confirmado = await sincronizador
                                      .reenviarParaServidor(idOperacao);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(SnackBar(
                                    content: Text(confirmado
                                        ? 'Pedido confirmado no servidor.'
                                        : 'O pedido continua pendente. Confira o motivo nesta tela.'),
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
