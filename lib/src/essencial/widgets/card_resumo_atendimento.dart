import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:flutter/material.dart';

class CardResumoAtendimento extends StatelessWidget {
  final String nome;
  final String cliente;
  final String codigo;
  final String? atendimento;
  final String? mesa;
  final String? total;
  final bool ocupada;
  final bool fechamento;
  final bool tipoMesa;
  final Widget tempo;
  final Widget? ultimoPedido;
  final VoidCallback onAbrir;
  final Widget? menu;

  const CardResumoAtendimento({
    super.key,
    required this.nome,
    required this.cliente,
    required this.codigo,
    required this.ocupada,
    required this.fechamento,
    required this.tipoMesa,
    required this.tempo,
    required this.onAbrir,
    this.atendimento,
    this.mesa,
    this.total,
    this.ultimoPedido,
    this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final cor = !ocupada
        ? VisualAtendimento.verde(context)
        : fechamento
            ? (Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFF2BE6C)
                : const Color(0xFF915900))
            : VisualAtendimento.azul(context);
    return Material(
      color: VisualAtendimento.superficie(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onAbrir,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusAtendimento(
                        texto: !ocupada ? 'Livre' : fechamento ? 'Em fechamento' : 'Ocupada',
                        cor: cor),
                    Text(nome, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    if (ocupada && atendimento != null)
                      Text(atendimento!.startsWith('local:') ? 'No aparelho' : '#$atendimento',
                          style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              if (menu != null)
                menu!
              else
                const SizedBox(
                    width: 32,
                    height: 40,
                    child: Icon(Icons.chevron_right_rounded, size: 20)),
            ]),
            if (ocupada) ...[
              const SizedBox(height: 2),
              _Linha(
                  icone: Icons.person_outline_rounded,
                  child: Text(cliente,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w500))),
            ],
            const SizedBox(height: 6),
            LayoutBuilder(builder: (context, constraints) {
              final tempos = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Linha(
                icone: ocupada ? Icons.schedule_rounded : Icons.history_rounded,
                child: tempo),
            if (ultimoPedido != null) ...[
              const SizedBox(height: 4),
              _Linha(
                  icone: Icons.restaurant_menu_rounded, child: ultimoPedido!),
            ],
              ]);
              if (!ocupada) return tempos;
              final valores = Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                if (mesa?.isNotEmpty == true)
                  Text(mesa!, textAlign: TextAlign.end,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cor)),
                if (total != null)
                  Text(total!, textAlign: TextAlign.end,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ]);
              if (MediaQuery.textScalerOf(context).scale(12) > 17 || constraints.maxWidth < 280) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  tempos, const SizedBox(height: 4), valores,
                ]);
              }
              return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: tempos), const SizedBox(width: 8),
                ConstrainedBox(constraints: BoxConstraints(maxWidth: constraints.maxWidth * .36), child: valores),
              ]);
            }),
          ]),
        ),
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final IconData icone;
  final Widget child;
  const _Linha({required this.icone, required this.child});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone,
              size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
              child: DefaultTextStyle.merge(
                  style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  child: child)),
        ],
      );
}
