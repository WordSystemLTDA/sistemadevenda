import 'package:flutter/material.dart';

class CardHome extends StatelessWidget {
  final String nome;
  final Function() onPressed;
  final Icon icone;
  final Color? cor;

  const CardHome({super.key, required this.nome, required this.onPressed, required this.icone, this.cor});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final destaque = cor ?? cs.primary;
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        padding: const EdgeInsets.all(16),
        side: BorderSide(color: cs.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: destaque.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icone.icon, size: 30, color: destaque),
          ),
          Row(
            children: [
              Expanded(child: Text(nome, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }
}
