import 'package:flutter/material.dart';

class BotaoAcaoPedido extends StatelessWidget {
  final String rotulo;
  final String total;
  final int? quantidade;
  final bool carregando;
  final VoidCallback onPressed;

  const BotaoAcaoPedido({
    super.key,
    required this.rotulo,
    required this.total,
    required this.onPressed,
    this.quantidade,
    this.carregando = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final corTexto = cs.onPrimary;

    return Semantics(
      button: true,
      enabled: !carregando,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: carregando ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: carregando
                  ? Center(
                      child: SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: corTexto,
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        if (quantidade != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: corTexto.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${quantidade}x',
                              style: TextStyle(
                                  color: corTexto,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          flex: 2,
                          child: Text(
                            rotulo,
                            maxLines: 2,
                            style: TextStyle(
                                color: corTexto,
                                fontWeight: FontWeight.w700,
                                fontSize: 15),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              total,
                              style: TextStyle(
                                  color: corTexto,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: corTexto, size: 22),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
