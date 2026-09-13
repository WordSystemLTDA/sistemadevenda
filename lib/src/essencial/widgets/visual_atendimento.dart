import 'package:flutter/material.dart';

abstract final class VisualAtendimento {
  static Color fundo(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF181A1D)
          : const Color(0xFFF5F6F7);

  static Color superficie(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF232629)
          : Colors.white;

  static Color verde(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF83D6B0)
          : const Color(0xFF187451);

  static Color azul(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF91C5F0)
          : const Color(0xFF286699);
}

class StatusAtendimento extends StatelessWidget {
  final String texto;
  final Color cor;
  final IconData icone;

  const StatusAtendimento({
    super.key,
    required this.texto,
    required this.cor,
    this.icone = Icons.circle,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icone, color: cor, size: icone == Icons.circle ? 6 : 14),
          const SizedBox(width: 6),
          Flexible(
            child: Text(texto,
                style: TextStyle(
                    color: cor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0)),
          ),
        ]),
      );
}
