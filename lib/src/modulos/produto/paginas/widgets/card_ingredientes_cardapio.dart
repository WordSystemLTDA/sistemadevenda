import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/montagem_ingrediente_cardapio.dart';
import 'package:flutter/material.dart';

class CardIngredientesCardapio extends StatelessWidget {
  final ModeloDadosOpcoesPacotes item;
  final ValueChanged<AcaoIngredienteCardapio> aoAlterar;
  final ValueChanged<bool> aoSeparar;
  final VoidCallback aoTrocar;
  final VoidCallback aoRestaurar;

  const CardIngredientesCardapio({
    super.key,
    required this.item,
    required this.aoAlterar,
    required this.aoSeparar,
    required this.aoTrocar,
    required this.aoRestaurar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final montagem = item.montagemCardapio ??
        MontagemIngredienteCardapio(nomeOriginal: item.nome);
    final alterado = montagem.acao != AcaoIngredienteCardapio.normal;
    final separado =
        montagem.separado && montagem.acao != AcaoIngredienteCardapio.sem;
    final cor = cs.primary;
    final permiteTrocar =
        item.permiteMontagemCardapio(AcaoIngredienteCardapio.trocar);

    final cabecalho = Row(children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: (alterado || separado ? cor : cs.onSurfaceVariant)
              .withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          montagem.acao == AcaoIngredienteCardapio.sem
              ? Icons.remove_circle_outline_rounded
              : Icons.restaurant_menu_rounded,
          size: 22,
          color: alterado || separado ? cor : cs.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            montagem.nomeOriginal,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (montagem.detalheVisualizacao != null) ...[
            const SizedBox(height: 4),
            Text(
              montagem.detalheVisualizacao!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.5,
                color: cor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ]),
      ),
      if (alterado || separado)
        IconButton(
          tooltip: 'Restaurar ingrediente',
          onPressed: aoRestaurar,
          icon: const Icon(Icons.undo_rounded, size: 20),
        ),
    ]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: VisualAtendimento.superficie(context),
        elevation: 1,
        shadowColor: cs.shadow.withValues(alpha: 0.10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: alterado || separado
                ? cor.withValues(alpha: 0.85)
                : cs.outlineVariant,
            width: alterado || separado ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecalho,
              const SizedBox(height: 14),
              Text(
                'QUANTIDADE NO PRATO',
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
              const SizedBox(height: 7),
              _ControlePorcaoIngrediente(
                item: item,
                selecionada: montagem.acao,
                aoAlterar: aoAlterar,
              ),
              const SizedBox(height: 8),
              Row(children: [
                if (permiteTrocar) ...[
                  Expanded(
                    child: _BotaoSecundarioIngrediente(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Trocar',
                      onPressed: aoTrocar,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: _BotaoSecundarioIngrediente(
                    icon: Icons.inventory_2_outlined,
                    label: 'Separado',
                    selecionado: separado,
                    onPressed: montagem.acao == AcaoIngredienteCardapio.sem
                        ? null
                        : () => aoSeparar(!separado),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlePorcaoIngrediente extends StatelessWidget {
  final ModeloDadosOpcoesPacotes item;
  final AcaoIngredienteCardapio selecionada;
  final ValueChanged<AcaoIngredienteCardapio> aoAlterar;

  const _ControlePorcaoIngrediente({
    required this.item,
    required this.selecionada,
    required this.aoAlterar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final acoes = <AcaoIngredienteCardapio>[
      AcaoIngredienteCardapio.sem,
      AcaoIngredienteCardapio.pouco,
      AcaoIngredienteCardapio.normal,
      AcaoIngredienteCardapio.mais,
    ].where(item.permiteMontagemCardapio).toList();

    final raio = BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: raio,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          border: Border.all(color: cs.outline.withValues(alpha: 0.70)),
          borderRadius: raio,
        ),
        child: SizedBox(
          height: 56,
          child: Row(children: [
            for (var i = 0; i < acoes.length; i++) ...[
              Expanded(
                child: _OpcaoPorcaoIngrediente(
                  acao: acoes[i],
                  selecionada: selecionada == acoes[i],
                  aoSelecionar: () => aoAlterar(acoes[i]),
                  borderRadius: i == 0
                      ? const BorderRadius.horizontal(left: Radius.circular(8))
                      : i == acoes.length - 1
                          ? const BorderRadius.horizontal(
                              right: Radius.circular(8))
                          : BorderRadius.zero,
                ),
              ),
              if (i < acoes.length - 1)
                Container(
                  width: 1,
                  color: cs.outline.withValues(alpha: 0.45),
                ),
            ],
          ]),
        ),
      ),
    );
  }
}

class _OpcaoPorcaoIngrediente extends StatelessWidget {
  final AcaoIngredienteCardapio acao;
  final bool selecionada;
  final VoidCallback aoSelecionar;
  final BorderRadius borderRadius;

  const _OpcaoPorcaoIngrediente({
    required this.acao,
    required this.selecionada,
    required this.aoSelecionar,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selecionada ? cs.primary : Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: aoSelecionar,
        borderRadius: borderRadius,
        child: Semantics(
          button: true,
          selected: selecionada,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selecionada) ...[
                    Icon(
                      Icons.check_circle_rounded,
                      size: 17,
                      color: cs.onPrimary,
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    acao.rotulo,
                    maxLines: 1,
                    style: TextStyle(
                      color: selecionada ? cs.onPrimary : cs.onSurface,
                      fontSize: 15,
                      fontWeight:
                          selecionada ? FontWeight.w800 : FontWeight.w700,
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

class _BotaoSecundarioIngrediente extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selecionado;
  final VoidCallback? onPressed;

  const _BotaoSecundarioIngrediente({
    required this.icon,
    required this.label,
    this.selecionado = false,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 54,
      child: Material(
        color: selecionado ? cs.primary : cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color:
                selecionado ? cs.primary : cs.outline.withValues(alpha: 0.65),
            width: selecionado ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Opacity(
            opacity: onPressed == null ? 0.45 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selecionado ? Icons.check_circle_rounded : icon,
                    size: 21,
                    color: selecionado ? cs.onPrimary : cs.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selecionado ? cs.onPrimary : cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
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
