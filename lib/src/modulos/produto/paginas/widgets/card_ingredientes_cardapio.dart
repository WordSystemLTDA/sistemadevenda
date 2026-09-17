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

    Widget controle(List<AcaoIngredienteCardapio> acoes) {
      return SegmentedButton<AcaoIngredienteCardapio>(
        showSelectedIcon: false,
        selected: acoes.contains(montagem.acao) ? {montagem.acao} : {},
        emptySelectionAllowed: true,
        onSelectionChanged: (selecionadas) {
          if (selecionadas.isNotEmpty) aoAlterar(selecionadas.first);
        },
        style: ButtonStyle(
          visualDensity: VisualDensity.compact,
          minimumSize: const WidgetStatePropertyAll(Size(48, 38)),
          padding:
              const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
        ),
        segments: [
          for (final acao in acoes)
            ButtonSegment(value: acao, label: Text(acao.rotulo)),
        ],
      );
    }

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
          padding: const EdgeInsets.all(10),
          child: LayoutBuilder(builder: (context, constraints) {
            final fonteAmpliada =
                MediaQuery.textScalerOf(context).scale(14) > 18;
            final botoes = Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (fonteAmpliada && constraints.maxWidth < 430)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      controle([
                        AcaoIngredienteCardapio.sem,
                        AcaoIngredienteCardapio.pouco,
                      ]),
                      const SizedBox(height: 8),
                      controle([
                        AcaoIngredienteCardapio.normal,
                        AcaoIngredienteCardapio.mais,
                      ]),
                    ],
                  )
                else
                  controle([
                    AcaoIngredienteCardapio.sem,
                    AcaoIngredienteCardapio.pouco,
                    AcaoIngredienteCardapio.normal,
                    AcaoIngredienteCardapio.mais,
                  ]),
                TextButton.icon(
                  onPressed: aoTrocar,
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Trocar'),
                ),
                FilterChip(
                  selected: separado,
                  onSelected: montagem.acao == AcaoIngredienteCardapio.sem
                      ? null
                      : aoSeparar,
                  label: const Text('Separado'),
                  avatar: const Icon(Icons.inventory_2_outlined, size: 18),
                ),
              ],
            );

            if (constraints.maxWidth < 640 || fonteAmpliada) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [cabecalho, const SizedBox(height: 10), botoes],
              );
            }

            return Row(children: [
              Expanded(child: cabecalho),
              const SizedBox(width: 12),
              Flexible(child: botoes),
            ]);
          }),
        ),
      ),
    );
  }
}
