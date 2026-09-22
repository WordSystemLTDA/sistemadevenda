import 'package:flutter/material.dart';

class CardHome extends StatelessWidget {
  const CardHome({
    super.key,
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.onPressed,
    this.decorado = false,
  });

  final String nome;
  final String descricao;
  final IconData icone;
  final Color cor;
  final VoidCallback onPressed;
  final bool decorado;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$nome. $descricao',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF123F53).withValues(alpha: 0.10),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          key: ValueKey('card-home-$nome'),
          color: cor,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                if (decorado)
                  Positioned(
                    right: -42,
                    top: -52,
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.09),
                          width: 20,
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: Icon(icone, size: 22, color: Colors.white),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.1,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              descricao,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.72),
                                fontSize: 12,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  right: 16,
                  bottom: 18,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CardAtalhoHome extends StatelessWidget {
  const CardAtalhoHome({
    super.key,
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.onPressed,
    this.mostrarSeta = false,
  });

  final String nome;
  final String descricao;
  final IconData icone;
  final VoidCallback onPressed;
  final bool mostrarSeta;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final corPrincipal = escuro ? cs.onSurface : const Color(0xFF123F53);

    return Semantics(
      button: true,
      label: '$nome. $descricao',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF123F53).withValues(alpha: 0.07),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Material(
          key: ValueKey('atalho-home-$nome'),
          color: escuro ? cs.surfaceContainerHigh : cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.8)),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: escuro
                          ? cs.surfaceContainerHighest
                          : const Color(0xFFEDF4F8),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icone, size: 21, color: corPrincipal),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nome,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: corPrincipal,
                            fontSize: 14,
                            height: 1.1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          descricao,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                            height: 1.1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (mostrarSeta) ...[
                    const SizedBox(width: 8),
                    Icon(Icons.chevron_right_rounded,
                        color: cs.onSurfaceVariant, size: 21),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
