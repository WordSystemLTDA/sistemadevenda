import 'package:flutter/material.dart';

class BotaoAcaoPedido extends StatelessWidget {
  final String rotulo;
  final String total;
  final IconData? iconeRotulo;
  final String? rotuloSemantico;
  final int? quantidade;
  final bool carregando;
  final VoidCallback onPressed;

  const BotaoAcaoPedido({
    super.key,
    required this.rotulo,
    required this.total,
    required this.onPressed,
    this.iconeRotulo,
    this.rotuloSemantico,
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
        constraints: const BoxConstraints(minHeight: 56),
        decoration: BoxDecoration(
          color: cs.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: carregando ? null : onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Preserva a altura do rotulo, inclusive quando ocupa duas linhas.
                  Visibility(
                    visible: !carregando,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: LayoutBuilder(builder: (context, constraints) {
                      final estiloRotulo = TextStyle(
                          color: corTexto,
                          fontWeight: FontWeight.w700,
                          fontSize: 15);
                      final estiloValor = TextStyle(
                          color: corTexto,
                          fontWeight: FontWeight.w700,
                          fontSize: 16);
                      final estiloQuantidade = TextStyle(
                          color: corTexto,
                          fontWeight: FontWeight.w800,
                          fontSize: 14);
                      double larguraTexto(String texto, TextStyle estilo) {
                        final painter = TextPainter(
                          text: TextSpan(text: texto, style: estilo),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout();
                        final largura = painter.width;
                        painter.dispose();
                        return largura;
                      }

                      final larguraQuantidade = quantidade == null
                          ? 0.0
                          : larguraTexto('${quantidade}x', estiloQuantidade) +
                              32;
                      final duasLinhas = larguraTexto(rotulo, estiloRotulo) +
                              (iconeRotulo == null ? 0 : 28) +
                              larguraTexto(total, estiloValor) +
                              larguraQuantidade +
                              38 >
                          constraints.maxWidth;
                      final Widget textoRotulo = iconeRotulo == null
                          ? Text(rotulo, style: estiloRotulo)
                          : Semantics(
                              label: rotuloSemantico ?? rotulo,
                              excludeSemantics: true,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                      child: Text(rotulo, style: estiloRotulo)),
                                  const SizedBox(width: 6),
                                  Icon(iconeRotulo, color: corTexto, size: 22),
                                ],
                              ),
                            );
                      final textoTotal = Text(total,
                          textAlign: TextAlign.end, style: estiloValor);
                      final contador = quantidade == null
                          ? null
                          : Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: corTexto.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text('${quantidade}x',
                                  style: estiloQuantidade),
                            );
                      final seta = Icon(Icons.arrow_forward_rounded,
                          color: corTexto, size: 22);

                      if (duasLinhas) {
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            textoRotulo,
                            const SizedBox(height: 6),
                            Row(children: [
                              if (contador != null) ...[
                                Flexible(child: contador),
                                const SizedBox(width: 8),
                              ],
                              Expanded(child: textoTotal),
                              const SizedBox(width: 8),
                              seta,
                            ]),
                          ],
                        );
                      }
                      return Row(children: [
                        if (contador != null) ...[
                          contador,
                          const SizedBox(width: 12),
                        ],
                        Expanded(child: textoRotulo),
                        const SizedBox(width: 8),
                        textoTotal,
                        const SizedBox(width: 8),
                        seta,
                      ]);
                    }),
                  ),
                  if (carregando)
                    Positioned.fill(
                      child: Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: corTexto,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
