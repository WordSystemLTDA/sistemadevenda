import 'package:flutter/material.dart';

import 'visual_atendimento.dart';

Color corAtencaoPendencias(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFFFCC80)
        : const Color(0xFF946000);

String quantidadeConferencia(Object? valor) {
  final numero = num.tryParse('${valor ?? 1}'.replaceAll(',', '.'));
  if (numero == null) return '${valor ?? 1}';
  return numero == numero.roundToDouble()
      ? numero.toInt().toString()
      : numero.toString().replaceAll('.', ',');
}

class CartaoPainelPendencias extends StatelessWidget {
  const CartaoPainelPendencias({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VisualAtendimento.superficie(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.6)),
        ),
        child: child,
      );
}

class IconePainelPendencias extends StatelessWidget {
  const IconePainelPendencias(
      {super.key, required this.icone, required this.cor});

  final IconData icone;
  final Color cor;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icone, color: cor, size: 23),
      );
}

class AvisoPainelPendencias extends StatelessWidget {
  const AvisoPainelPendencias({
    super.key,
    required this.texto,
    required this.cor,
    this.icone = Icons.info_outline,
  });

  final String texto;
  final Color cor;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icone, color: cor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texto,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Theme.of(context).colorScheme.onSurface)),
          ),
        ]),
      );
}

class TituloPainelPendencias extends StatelessWidget {
  const TituloPainelPendencias(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 10),
        child: Text(texto,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}
