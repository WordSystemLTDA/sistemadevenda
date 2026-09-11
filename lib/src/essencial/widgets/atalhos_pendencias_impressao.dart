import 'dart:async';

import 'package:app/src/essencial/api/socket/fila_impressao.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CartaoPendenciasImpressao extends StatefulWidget {
  const CartaoPendenciasImpressao({super.key, this.fila, this.onAbrir});

  final FilaImpressao? fila;
  final void Function(BuildContext context)? onAbrir;

  @override
  State<CartaoPendenciasImpressao> createState() =>
      _CartaoPendenciasImpressaoState();
}

class _CartaoPendenciasImpressaoState extends State<CartaoPendenciasImpressao> {
  late final Server? _server;
  late final FilaImpressao _fila;

  @override
  void initState() {
    super.initState();
    if (widget.fila != null) {
      _server = null;
      _fila = widget.fila!;
    } else {
      final server = Modular.get<Server>();
      _server = server;
      _fila = server.filaImpressao;
    }
    unawaited(_fila.carregar());
  }

  void _abrirPendencias(BuildContext context) {
    final onAbrir = widget.onAbrir;
    if (onAbrir != null) {
      onAbrir(context);
      return;
    }
    _server?.abrirPendenciasImpressao(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListenableBuilder(
      listenable: _fila,
      builder: (context, _) {
        final quantidade = _fila.itens.length;
        final temPendencia = quantidade > 0;
        final corDestaque = temPendencia ? cs.error : cs.primary;
        final subtitulo = temPendencia
            ? '$quantidade ${quantidade == 1 ? 'impressão aguardando' : 'impressões aguardando'}'
            : 'Nenhuma pendência agora';

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Material(
              key: const ValueKey('card_pendencias_impressao'),
              color: isDark ? const Color(0xFF1F2937) : cs.surface,
              elevation: temPendencia ? 5 : 2,
              shadowColor: corDestaque.withValues(alpha: 0.18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: temPendencia
                      ? corDestaque.withValues(alpha: 0.35)
                      : cs.outlineVariant,
                ),
              ),
              child: InkWell(
                onTap: () => _abrirPendencias(context),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: corDestaque.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.print_outlined,
                            color: corDestaque, size: 26),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Impressões Pendentes',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface,
                                  ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        key: const ValueKey('contador_pendencias_impressao'),
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 34),
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: corDestaque.withValues(alpha: 0.13),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$quantidade',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: corDestaque,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.chevron_right_rounded,
                          color: cs.onSurfaceVariant, size: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class BotaoFlutuantePendenciasImpressao extends StatefulWidget {
  const BotaoFlutuantePendenciasImpressao({
    super.key,
    required this.tag,
    this.fila,
    this.onAbrir,
  });

  final String tag;
  final FilaImpressao? fila;
  final void Function(BuildContext context)? onAbrir;

  @override
  State<BotaoFlutuantePendenciasImpressao> createState() =>
      _BotaoFlutuantePendenciasImpressaoState();
}

class _BotaoFlutuantePendenciasImpressaoState
    extends State<BotaoFlutuantePendenciasImpressao> {
  late final Server? _server;
  late final FilaImpressao _fila;

  @override
  void initState() {
    super.initState();
    if (widget.fila != null) {
      _server = null;
      _fila = widget.fila!;
    } else {
      final server = Modular.get<Server>();
      _server = server;
      _fila = server.filaImpressao;
    }
    unawaited(_fila.carregar());
  }

  void _abrirPendencias(BuildContext context) {
    final onAbrir = widget.onAbrir;
    if (onAbrir != null) {
      onAbrir(context);
      return;
    }
    _server?.abrirPendenciasImpressao(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: _fila,
      builder: (context, _) {
        final quantidade = _fila.itens.length;
        final temPendencia = quantidade > 0;
        final corFundo = temPendencia ? cs.error : cs.primary;
        final corBotao = corFundo.withValues(alpha: temPendencia ? 0.62 : 0.52);

        return Semantics(
          button: true,
          label: temPendencia
              ? '$quantidade impressões pendentes'
              : 'Impressões pendentes',
          child: Tooltip(
            message: 'Impressões pendentes',
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  key: ValueKey('botao_pendencias_impressao_${widget.tag}'),
                  color: corBotao,
                  elevation: 3,
                  shadowColor: corFundo.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                  child: InkWell(
                    onTap: () => _abrirPendencias(context),
                    borderRadius: BorderRadius.circular(18),
                    child: const SizedBox(
                      width: 58,
                      height: 58,
                      child: Icon(Icons.print_outlined,
                          color: Colors.white, size: 30),
                    ),
                  ),
                ),
                if (temPendencia)
                  Positioned(
                    top: -7,
                    right: -7,
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 24, minHeight: 24),
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade700,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Text(
                        '$quantidade',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
