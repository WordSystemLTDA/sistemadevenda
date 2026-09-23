import 'package:app/src/essencial/widgets/grade_opcoes_responsiva.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ListaBordas extends StatefulWidget {
  final ProvedorCardapio? cardapio;
  final ProvedorProduto? produto;
  final int? limite;
  final ValueChanged<int>? aoSelecionarLimite;
  const ListaBordas(
      {super.key,
      this.cardapio,
      this.produto,
      this.limite,
      this.aoSelecionarLimite});

  @override
  State<ListaBordas> createState() => _ListaBordasState();
}

class _ListaBordasState extends State<ListaBordas> {
  late final provedor = widget.cardapio ?? Modular.get<ProvedorCardapio>();
  late final provedorProduto = widget.produto ?? Modular.get<ProvedorProduto>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provedor,
      builder: (context, snapshot) {
        final limiteConfigurado = widget.limite ??
            int.tryParse(provedor.configBigchef?.saborlimitedeborda ?? '') ??
            0;
        return ListenableBuilder(
          listenable: provedorProduto,
          builder: (context, snapshot) {
            return GradeOpcoesResponsiva(
              children: List.generate(limiteConfigurado, (index) {
                return Badge(
                  label: (index + 1) == provedor.limiteSaborBordaSelecionado
                      ? const Icon(Icons.check, color: Colors.white, size: 14)
                      : null,
                  backgroundColor: Colors.green,
                  alignment: AlignmentDirectional.topEnd,
                  offset: const Offset(-10, 4),
                  padding: const EdgeInsets.only(bottom: 2, top: 2),
                  smallSize: 0,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 70),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: (index + 1) ==
                                  provedor.limiteSaborBordaSelecionado
                              ? Colors.green
                              : Colors.grey),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: InkWell(
                      onTap: () {
                        final aoSelecionarLimite = widget.aoSelecionarLimite;
                        if (aoSelecionarLimite != null) {
                          aoSelecionarLimite(index + 1);
                          return;
                        }
                        ScaffoldMessenger.of(context).removeCurrentSnackBar();
                        final limiteAnterior =
                            provedor.limiteSaborBordaSelecionado;

                        if (provedor.limiteSaborBordaSelecionado ==
                            (index + 1)) {
                          provedor.limiteSaborBordaSelecionado = 0;
                          var listaF = provedorProduto.opcoesPacotesListaFinal;
                          listaF
                              .where((element) => element.id == 6)
                              .firstOrNull
                              ?.dados = [];

                          provedorProduto.opcoesPacotesListaFinal = listaF;
                        } else {
                          provedor.limiteSaborBordaSelecionado = (index + 1);
                        }

                        if (limiteAnterior !=
                            provedor.limiteSaborBordaSelecionado) {
                          FeedbackUsuario.selecaoAlterada();
                        }

                        // print((widget.opcoesPacotesListaFinal.where((element) => element.id == 6).firstOrNull?.dados?.length ?? 0));

                        if ((provedorProduto.opcoesPacotesListaFinal
                                    .where((element) => element.id == 6)
                                    .firstOrNull
                                    ?.dados
                                    ?.length ??
                                0) >
                            (index + 1)) {
                          var listaF = provedorProduto.opcoesPacotesListaFinal;
                          listaF
                              .where((element) => element.id == 6)
                              .firstOrNull
                              ?.dados = [];

                          provedorProduto.opcoesPacotesListaFinal = listaF;
                        }
                      },
                      child: Row(
                        children: [
                          SizedBox(
                            width: 60,
                            height: 54,
                            child: SfCircularChart(
                              margin: const EdgeInsets.all(4),
                              series: [
                                DoughnutSeries(
                                  dataSource: List.generate(
                                    (index + 1),
                                    (index2) {
                                      var cores = {
                                        0: Colors.black,
                                        1: Colors.red,
                                        2: Colors.deepPurple,
                                        3: Colors.blue,
                                        4: Colors.orange,
                                        5: Colors.yellow,
                                      };

                                      if ((index + 1) ==
                                              provedor
                                                  .limiteSaborBordaSelecionado &&
                                          (index2 + 1) <=
                                              (provedorProduto
                                                          .opcoesPacotesListaFinal
                                                          .where((element) =>
                                                              element.id == 6)
                                                          .firstOrNull
                                                          ?.dados ??
                                                      [])
                                                  .length) {
                                        return {
                                          'x': '',
                                          'y': 10,
                                          'color': cores[index2 + 1]
                                        };
                                      }

                                      return {
                                        'x': '',
                                        'y': 10,
                                        'color': Colors.transparent
                                      };
                                    },
                                  ),
                                  explode: false,
                                  explodeIndex: 0,
                                  innerRadius: '60%',
                                  animationDuration: 0,
                                  cornerStyle: CornerStyle.bothCurve,
                                  startAngle: 90,
                                  endAngle: 90,
                                  strokeColor: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Colors.white
                                      : Colors.black,
                                  strokeWidth: 0.5,
                                  pointColorMapper: (data, index) =>
                                      data['color'],
                                  xValueMapper: (data, _) =>
                                      data['x'] as String,
                                  yValueMapper: (data, _) => data['y'],
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                              child: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                          provedor.tamanhosPizza
                                                  ?.nomedotamanho ??
                                              '',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold)),
                                      Text(
                                        "${index + 1 > 1 ? 'até ' : ''}${index + 1} ${index + 1 > 1 ? 'sabores' : 'sabor'}",
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ))),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        );
      },
    );
  }
}

class ControleMeiaBorda extends StatelessWidget {
  final ProvedorProduto? produto;
  final bool kit;
  final String idProduto;

  const ControleMeiaBorda({
    super.key,
    this.produto,
    this.kit = false,
    this.idProduto = '0',
  });

  @override
  Widget build(BuildContext context) {
    final provedorProduto = produto ?? Modular.get<ProvedorProduto>();

    return ListenableBuilder(
      listenable: provedorProduto,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final somenteMetade =
            provedorProduto.bordaSomenteMetadeSelecionada(kit, idProduto);
        final totalBordas = provedorProduto.calcularPrecoBorda();
        final totalTexto = totalBordas.obterReal();
        final descricao = somenteMetade
            ? 'Meia pizza selecionada'
            : 'Pizza inteira selecionada';

        final seletor = SegmentedButton<bool>(
          key: const ValueKey('controle_meia_borda_seletor'),
          showSelectedIcon: false,
          expandedInsets: EdgeInsets.zero,
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: cs.primaryContainer,
            selectedForegroundColor: cs.onPrimaryContainer,
            foregroundColor: cs.onSurfaceVariant,
            side: BorderSide(color: cs.outlineVariant),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          segments: const [
            ButtonSegment<bool>(
              value: false,
              icon: Icon(Icons.radio_button_checked_outlined),
              label: Text('Inteira'),
            ),
            ButtonSegment<bool>(
              value: true,
              icon: Icon(Icons.adjust_outlined),
              label: Text('Meia'),
            ),
          ],
          selected: {somenteMetade},
          onSelectionChanged: (selecionado) {
            provedorProduto.definirBordaSomenteMetade(
              selecionado.single,
              kit,
              idProduto,
            );
            FeedbackUsuario.selecaoAlterada();
          },
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
          child: Material(
            key: const ValueKey('controle_meia_borda_card'),
            color: cs.surfaceContainerHighest.withValues(alpha: 0.45),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.7)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.local_pizza_outlined,
                            size: 19, color: cs.onPrimaryContainer),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Aplicação da borda',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface)),
                            const SizedBox(height: 2),
                            Text(
                              '$descricao • Cobrança: $totalTexto',
                              style: TextStyle(
                                  fontSize: 12.5, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  seletor,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
