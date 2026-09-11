import 'package:flutter/material.dart';

class LinhaValor extends StatelessWidget {
  final Widget descricao;
  final Widget valor;

  const LinhaValor({
    super.key,
    required this.descricao,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final escala = MediaQuery.textScalerOf(context).scale(16) / 16;
      if (constraints.maxWidth / escala < 300) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            descricao,
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: valor),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 3, child: descricao),
          const SizedBox(width: 12),
          Flexible(
            flex: 2,
            child: Align(alignment: Alignment.centerRight, child: valor),
          ),
        ],
      );
    });
  }
}
