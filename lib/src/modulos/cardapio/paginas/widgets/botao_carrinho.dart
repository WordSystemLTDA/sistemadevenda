import 'dart:async';

import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';

class BotaoCarrinho extends StatefulWidget {
  final num quantidade;
  final int numeroAdicoes;
  final bool expandido;
  final VoidCallback onPressed;

  const BotaoCarrinho({
    super.key,
    required this.quantidade,
    required this.numeroAdicoes,
    this.expandido = false,
    required this.onPressed,
  });

  @override
  State<BotaoCarrinho> createState() => _BotaoCarrinhoState();
}

class _BotaoCarrinhoState extends State<BotaoCarrinho>
    with SingleTickerProviderStateMixin {
  late final _animacao = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );
  late final _escala = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 1.15), weight: 40),
    TweenSequenceItem(tween: Tween(begin: 1.15, end: 1), weight: 60),
  ]).animate(CurvedAnimation(parent: _animacao, curve: Curves.easeInOut));
  Timer? _temporizador;
  bool _adicionado = false;

  @override
  void didUpdateWidget(covariant BotaoCarrinho oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.numeroAdicoes > oldWidget.numeroAdicoes) {
      _temporizador?.cancel();
      _adicionado = true;
      if (!MediaQuery.disableAnimationsOf(context)) {
        _animacao.forward(from: 0);
      }
      FeedbackUsuario.produtoAdicionado();
      _temporizador = Timer(const Duration(milliseconds: 1800), () {
        if (mounted) setState(() => _adicionado = false);
      });
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _animacao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final duracao = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        ScaleTransition(
          scale: _escala,
          child: badges.Badge(
            ignorePointer: true,
            badgeAnimation: const badges.BadgeAnimation.scale(toAnimate: false),
            badgeContent: Text(
              widget.quantidade.toStringAsFixed(0),
              style: TextStyle(
                  color: cs.onError, fontSize: 11, fontWeight: FontWeight.w700),
            ),
            badgeStyle: badges.BadgeStyle(
              badgeColor: cs.error,
              padding: const EdgeInsets.all(6),
              elevation: 2,
            ),
            position: badges.BadgePosition.topEnd(end: -2, top: -2),
            child: SizedBox(
              width: widget.expandido ? 144 : 56,
              height: 56,
              child: widget.expandido
                  ? FloatingActionButton.extended(
                      heroTag: null,
                      tooltip: 'Abrir carrinho',
                      backgroundColor:
                          _adicionado ? Colors.green.shade700 : cs.primary,
                      foregroundColor:
                          _adicionado ? Colors.white : cs.onPrimary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onPressed: widget.onPressed,
                      icon: AnimatedSwitcher(
                        duration: duracao,
                        child: Icon(
                          _adicionado
                              ? Icons.check_rounded
                              : Icons.shopping_cart_outlined,
                          key: ValueKey(_adicionado),
                          size: 24,
                        ),
                      ),
                      label: Text(
                        _adicionado ? 'Adicionado' : 'Carrinho',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : FloatingActionButton(
                      heroTag: null,
                      tooltip: 'Abrir carrinho',
                      backgroundColor:
                          _adicionado ? Colors.green.shade700 : cs.primary,
                      foregroundColor:
                          _adicionado ? Colors.white : cs.onPrimary,
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      onPressed: widget.onPressed,
                      child: AnimatedSwitcher(
                        duration: duracao,
                        child: Icon(
                          _adicionado
                              ? Icons.check_rounded
                              : Icons.shopping_cart_outlined,
                          key: ValueKey(_adicionado),
                          size: 24,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        Positioned(
          bottom: 70,
          right: 0,
          child: IgnorePointer(
            child: AnimatedOpacity(
              opacity: _adicionado ? 1 : 0,
              duration: duracao,
              child: Semantics(
                liveRegion: true,
                hidden: !_adicionado,
                child: Material(
                  color: Colors.green.shade700,
                  borderRadius: BorderRadius.circular(8),
                  elevation: 3,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width - 96,
                          ),
                          child: const Text('Adicionado ao carrinho',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
