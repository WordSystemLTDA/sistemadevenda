import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ListaTamanhosPizza extends StatefulWidget {
  final ModeloCategoria categoria;
  const ListaTamanhosPizza({super.key, required this.categoria});

  @override
  State<ListaTamanhosPizza> createState() => _ListaTamanhosPizzaState();
}

class _ListaTamanhosPizzaState extends State<ListaTamanhosPizza> {
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: widget.categoria.tamanhosPizza!.map((e) {
          final selected = provedorCardapio.tamanhosPizza?.id == e.id;
          return Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 8, top: 4),
            child: Badge(
              label: selected
                  ? Icon(Icons.check_rounded, color: colorScheme.onPrimary, size: 14)
                  : null,
              backgroundColor: colorScheme.primary,
              alignment: const Alignment(1, -1),
              padding: const EdgeInsets.all(4),
              smallSize: 0,
              child: Material(
                color: selected
                    ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                    : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () {
                    if (provedorCardapio.tamanhosPizza == e) {
                      provedorCardapio.tamanhosPizza = null;
                      provedorCardapio.saboresPizzaSelecionados = [];
                    } else {
                      provedorCardapio.tamanhosPizza = e;
                    }
                    if (provedorCardapio.saboresPizzaSelecionados.length >
                        int.parse(e.saboreslimite)) {
                      provedorCardapio.saboresPizzaSelecionados = [];
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 180,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? colorScheme.primary
                            : colorScheme.outlineVariant.withValues(alpha: 0.5),
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          height: 90,
                          child: SfCircularChart(
                            series: [
                              PieSeries(
                                dataSource: List.generate(
                                  e.id == provedorCardapio.tamanhosPizza?.id
                                      ? provedorCardapio
                                              .saboresPizzaSelecionados.isEmpty
                                          ? 1
                                          : provedorCardapio
                                              .saboresPizzaSelecionados.length
                                      : int.parse(e.saboreslimite),
                                  (index2) {
                                    var cores = {
                                      0: Colors.black,
                                      1: Colors.red,
                                      2: Colors.deepPurple,
                                      3: Colors.blue,
                                      4: Colors.orange,
                                      5: Colors.yellow,
                                    };
                                    if (e.id == provedorCardapio.tamanhosPizza?.id &&
                                        (index2 + 1) <=
                                            provedorCardapio
                                                .saboresPizzaSelecionados.length) {
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
                                animationDuration: 0,
                                startAngle: 90,
                                endAngle: 90,
                                strokeColor: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white
                                    : Colors.black,
                                strokeWidth: 0.5,
                                pointColorMapper: (data, index) =>
                                    data['color'] as Color,
                                xValueMapper: (data, _) => data['x'] as String,
                                yValueMapper: (data, _) => data['y'] as int,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              e.nomedotamanho,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${e.quantpedacos} Pedaços',
                              style: const TextStyle(fontSize: 10),
                            ),
                            Text(
                              '${int.parse(e.saboreslimite) > 1 ? 'até ' : ''}${int.parse(e.saboreslimite)} ${int.parse(e.saboreslimite) > 1 ? 'sabores' : 'sabor'}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
