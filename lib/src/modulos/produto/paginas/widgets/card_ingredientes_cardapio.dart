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

    final cabecalho = Row(children: [
      Icon(
        montagem.acao == AcaoIngredienteCardapio.sem
            ? Icons.remove_circle_outline
            : Icons.restaurant_menu_outlined,
        size: 20,
        color: alterado || separado ? cor : cs.onSurfaceVariant,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            montagem.nomeOriginal,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          if (montagem.detalheVisualizacao != null) ...[
            const SizedBox(height: 3),
            Text(
              montagem.detalheVisualizacao!,
              style: TextStyle(
                  fontSize: 12.5, color: cor, fontWeight: FontWeight.w600),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(
            color: alterado || separado
                ? cor.withValues(alpha: 0.75)
                : cs.outlineVariant.withValues(alpha: 0.7),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cabecalho,
              const SizedBox(height: 10),
              _ControlePorcaoIngrediente(
                selecionada: montagem.acao,
                aoAlterar: aoAlterar,
              ),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                  child: _BotaoSecundarioIngrediente(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Trocar',
                    onPressed: aoTrocar,
                  ),
                ),
                const SizedBox(width: 8),
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
  final AcaoIngredienteCardapio selecionada;
  final ValueChanged<AcaoIngredienteCardapio> aoAlterar;

  const _ControlePorcaoIngrediente({
    required this.selecionada,
    required this.aoAlterar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const acoes = [
      AcaoIngredienteCardapio.sem,
      AcaoIngredienteCardapio.pouco,
      AcaoIngredienteCardapio.normal,
      AcaoIngredienteCardapio.mais,
    ];

    final raio = BorderRadius.circular(8);

    return ClipRRect(
      borderRadius: raio,
      child: Container(
        foregroundDecoration: BoxDecoration(
          border: Border.all(color: cs.outline.withValues(alpha: 0.75)),
          borderRadius: raio,
        ),
        child: SizedBox(
          height: 52,
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
                  color: cs.outline.withValues(alpha: 0.55),
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
      color: selecionada ? cs.primaryContainer : Colors.transparent,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: aoSelecionar,
        borderRadius: borderRadius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Text(
                acao.rotulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selecionada ? cs.primary : cs.onSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (selecionada)
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: cs.outline.withValues(alpha: 0.75),
                      ),
                      borderRadius: borderRadius,
                    ),
                  ),
                ),
              ),
          ],
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
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: selecionado ? cs.primary : cs.onSurfaceVariant,
          backgroundColor: selecionado
              ? cs.primaryContainer.withValues(alpha: 0.55)
              : cs.surface,
          side: BorderSide(
            color: selecionado ? cs.primary : cs.outlineVariant,
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
