import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

typedef AcaoAtualizacao = Future<bool> Function();

Future<void> exibirDialogoAtualizacaoDisponivel({
  required BuildContext context,
  required String versaoInstalada,
  required String versaoDisponivel,
  required AcaoAtualizacao onAtualizar,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => DialogoAtualizacaoDisponivel(
      versaoInstalada: versaoInstalada,
      versaoDisponivel: versaoDisponivel,
      onAtualizar: onAtualizar,
    ),
  );
}

Future<bool> abrirLinkExternoAtualizacao(String link) async {
  final uri = Uri.tryParse(link.trim());
  if (uri == null || !uri.hasScheme || !await canLaunchUrl(uri)) return false;

  return launchUrl(uri, mode: LaunchMode.externalApplication);
}

class DialogoAtualizacaoDisponivel extends StatefulWidget {
  const DialogoAtualizacaoDisponivel({
    super.key,
    required this.versaoInstalada,
    required this.versaoDisponivel,
    required this.onAtualizar,
  });

  final String versaoInstalada;
  final String versaoDisponivel;
  final AcaoAtualizacao onAtualizar;

  @override
  State<DialogoAtualizacaoDisponivel> createState() =>
      _DialogoAtualizacaoDisponivelState();
}

class _DialogoAtualizacaoDisponivelState
    extends State<DialogoAtualizacaoDisponivel> {
  bool _executando = false;
  String? _mensagemErro;

  Future<void> _executar(AcaoAtualizacao acao) async {
    if (_executando) return;

    setState(() {
      _executando = true;
      _mensagemErro = null;
    });

    var sucesso = false;
    try {
      sucesso = await acao();
    } catch (_) {
      sucesso = false;
    }

    if (!mounted) return;
    setState(() {
      _executando = false;
      if (!sucesso) {
        _mensagemErro =
            'Não foi possível abrir a atualização. Verifique sua conexão ou entre em contato com o suporte.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final escuro = tema.brightness == Brightness.dark;
    final alturaDisponivel = MediaQuery.sizeOf(context).height - 40;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      backgroundColor: escuro ? cores.surface : const Color(0xFFFCFAFF),
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 440,
          maxHeight: alturaDisponivel > 0 ? alturaDisponivel : 1,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cores.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Icons.system_update_alt_rounded,
                      size: 30,
                      color: cores.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: cores.primaryContainer.withValues(
                              alpha: escuro ? 0.5 : 0.75,
                            ),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            'ATUALIZAÇÃO DISPONÍVEL',
                            style: tema.textTheme.labelSmall?.copyWith(
                              color: cores.onPrimaryContainer,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Uma nova versão está pronta',
                          style: tema.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Atualize para receber as correções e melhorias mais recentes do aplicativo.',
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: cores.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              _ComparacaoVersoes(
                versaoInstalada: widget.versaoInstalada,
                versaoDisponivel: widget.versaoDisponivel,
              ),
              const SizedBox(height: 18),
              Text(
                'Antes de atualizar',
                style: tema.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 11),
              const _ItemInformacao(
                icone: Icons.wifi_rounded,
                texto: 'Mantenha o aparelho conectado à internet.',
              ),
              const SizedBox(height: 10),
              const _ItemInformacao(
                icone: Icons.verified_user_outlined,
                texto: 'Sua conta e seus pedidos permanecem disponíveis.',
              ),
              const SizedBox(height: 10),
              const _ItemInformacao(
                icone: Icons.restart_alt_rounded,
                texto: 'Após instalar, abra novamente o aplicativo.',
              ),
              if (_mensagemErro != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: cores.errorContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: cores.onErrorContainer,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _mensagemErro!,
                          style: tema.textTheme.bodySmall?.copyWith(
                            color: cores.onErrorContainer,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('atualizar-agora'),
                onPressed:
                    _executando ? null : () => _executar(widget.onAtualizar),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                icon: _executando
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: cores.onPrimary,
                        ),
                      )
                    : const Icon(Icons.open_in_new_rounded),
                label:
                    Text(_executando ? 'Abrindo...' : 'Atualizar aplicativo'),
              ),
              const SizedBox(height: 12),
              Text(
                'Você será direcionado para a página segura de atualização.',
                textAlign: TextAlign.center,
                style: tema.textTheme.bodySmall?.copyWith(
                  color: cores.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ComparacaoVersoes extends StatelessWidget {
  const _ComparacaoVersoes({
    required this.versaoInstalada,
    required this.versaoDisponivel,
  });

  final String versaoInstalada;
  final String versaoDisponivel;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cores.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cores.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Versao(
              titulo: 'Instalada',
              versao: versaoInstalada,
              cor: cores.onSurfaceVariant,
            ),
          ),
          Container(
            width: 34,
            height: 34,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: cores.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 19,
              color: cores.primary,
            ),
          ),
          Expanded(
            child: _Versao(
              titulo: 'Nova versão',
              versao: versaoDisponivel,
              cor: cores.primary,
              alinharFim: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _Versao extends StatelessWidget {
  const _Versao({
    required this.titulo,
    required this.versao,
    required this.cor,
    this.alinharFim = false,
  });

  final String titulo;
  final String versao;
  final Color cor;
  final bool alinharFim;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment:
          alinharFim ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.labelMedium?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          versao,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: tema.textTheme.titleMedium?.copyWith(
            color: cor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _ItemInformacao extends StatelessWidget {
  const _ItemInformacao({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tema.colorScheme.primaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icone,
            size: 17,
            color: tema.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              texto,
              style: tema.textTheme.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}
