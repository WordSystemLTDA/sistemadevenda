import 'package:flutter/material.dart';

class IndicadorPedidoRecorrente extends StatelessWidget {
  const IndicadorPedidoRecorrente({super.key});

  @override
  Widget build(BuildContext context) {
    final cor = Theme.of(context).colorScheme.primary;
    return Tooltip(
      message: 'Pedido gerado por recorrência',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.repeat_rounded, size: 14, color: cor),
          const SizedBox(width: 4),
          Text('Recorrente',
              style:
                  Theme.of(context).textTheme.bodySmall?.copyWith(color: cor)),
        ],
      ),
    );
  }
}
