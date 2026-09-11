import 'package:flutter/material.dart';

class GradeOpcoesResponsiva extends StatelessWidget {
  final List<Widget> children;

  const GradeOpcoesResponsiva({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: LayoutBuilder(builder: (context, constraints) {
        const espaco = 12.0;
        final escala = MediaQuery.textScalerOf(context).scale(13) / 13;
        final larguraMinima = 160 * escala.clamp(1.0, 2.5);
        final colunas =
            ((constraints.maxWidth + espaco) / (larguraMinima + espaco))
                .floor()
                .clamp(1, 4);
        final largura =
            (constraints.maxWidth - espaco * (colunas - 1)) / colunas;

        return Wrap(
          spacing: espaco,
          runSpacing: espaco,
          children: [
            for (final child in children)
              SizedBox(width: largura, child: child),
          ],
        );
      }),
    );
  }
}
