import 'package:flutter/material.dart';

class BadgeValorOculto extends StatelessWidget {
  final bool compact;
  final String? label;

  const BadgeValorOculto({
    super.key,
    this.compact = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corFundo = Colors.grey[300]?.withValues(alpha: isDark ? 0.15 : 0.20);
    final corBorda = Colors.grey[400]?.withValues(alpha: isDark ? 0.30 : 0.15) ?? Colors.grey;
    final corTexto = Colors.grey[600];
    final corIcone = Colors.grey[500];

    final padding = compact ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4) : const EdgeInsets.symmetric(horizontal: 12, vertical: 6);
    final fontSize = compact ? 11.0 : 12.0;
    final iconSize = compact ? 12.0 : 14.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: corBorda, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: iconSize, color: corIcone),
          const SizedBox(width: 4),
          Text(
            label ?? 'Valor',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: corTexto,
              letterSpacing: 0.05,
            ),
          ),
        ],
      ),
    );
  }
}
