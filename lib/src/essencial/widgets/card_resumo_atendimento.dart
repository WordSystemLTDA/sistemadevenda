import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/linha_valor.dart';

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
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(
                  tipoMesa
                      ? Icons.table_restaurant_outlined
                      : Icons.receipt_long_outlined,
                  color: cor,
                  size: 22),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(nome,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700))),
              if (menu != null)
                menu!
              else
                const SizedBox(
                    width: 32,
                    height: 36,
                    child: Icon(Icons.chevron_right_rounded, size: 20)),
            ]),
            const SizedBox(height: 4),
            Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusAtendimento(
                      texto: !ocupada
                          ? 'Livre'
                          : fechamento
                              ? 'Em fechamento'
                              : 'Ocupada',
                      cor: cor),
                  if (ocupada && atendimento?.startsWith('local:') == true)
                    StatusAtendimento(
                        texto: 'No aparelho',
                        cor: cs.onSurfaceVariant,
                        icone: Icons.cloud_upload_outlined)
                  else if (ocupada && atendimento != null)
                    Text('#$atendimento',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  if (codigo.isNotEmpty)
                    Text('Código: $codigo',
                        style: TextStyle(
                            fontSize: 12, color: cs.onSurfaceVariant)),
                  if (mesa?.isNotEmpty == true)
                    StatusAtendimento(
                        texto: mesa!,
                        cor: VisualAtendimento.azul(context),
                        icone: Icons.table_restaurant_outlined),
                ]),
            if (ocupada) ...[
              const SizedBox(height: 12),
              _Linha(
                  icone: Icons.person_outline_rounded,
                  child: total == null
                      ? Text(cliente,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w500))
                      : LinhaValor(
                          descricao: Text(cliente,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w500)),
                          valor: Text(total!,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700)),
                        )),
            ],
            const SizedBox(height: 8),
            _Linha(
                icone: ocupada ? Icons.schedule_rounded : Icons.history_rounded,
                child: tempo),
            if (ultimoPedido != null) ...[
              const SizedBox(height: 6),
              _Linha(
                  icone: Icons.restaurant_menu_rounded, child: ultimoPedido!),
            ],
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
