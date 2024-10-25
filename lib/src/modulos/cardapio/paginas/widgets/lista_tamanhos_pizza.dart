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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: widget.categoria.tamanhosPizza!.map((e) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Badge(
            label: provedorCardapio.tamanhosPizza?.id == e.id ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
            backgroundColor: Colors.green,
            alignment: const Alignment(1, -1),
            padding: const EdgeInsets.only(bottom: 2, top: 2),
            smallSize: 0,
            child: Container(
              width: 180,
              height: 70,
              decoration: BoxDecoration(
                border: Border.all(color: provedorCardapio.tamanhosPizza?.id == e.id ? Colors.green : Colors.grey),
                borderRadius: BorderRadius.circular(3),
              ),
              child: InkWell(
                onTap: () {
                  if (provedorCardapio.tamanhosPizza == e) {
                    provedorCardapio.tamanhosPizza = null;
                    provedorCardapio.saboresPizzaSelecionados = [];
                  } else {
                    provedorCardapio.tamanhosPizza = e;
                  }

                  if (provedorCardapio.saboresPizzaSelecionados.length > int.parse(e.saboreslimite)) {
                    provedorCardapio.saboresPizzaSelecionados = [];
                  }
                },
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
                                  ? provedorCardapio.saboresPizzaSelecionados.isEmpty
                                      ? 1
                                      : provedorCardapio.saboresPizzaSelecionados.length
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

                                if (e.id == provedorCardapio.tamanhosPizza?.id && (index2 + 1) <= provedorCardapio.saboresPizzaSelecionados.length) {
                                  return {'x': '', 'y': 10, 'color': cores[index2 + 1]};
                                }

                                return {'x': '', 'y': 10, 'color': Colors.transparent};
                              },
                            ),
                            explode: false,
                            explodeIndex: 0,
                            animationDuration: 0,
                            startAngle: 90,
                            endAngle: 90,
                            strokeColor: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black,
                            strokeWidth: 0.5,
                            pointColorMapper: (data, index) => data['color'],
                            xValueMapper: (data, _) => data['x'] as String,
                            yValueMapper: (data, _) => data['y'],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(e.nomedotamanho, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text("${e.quantpedacos} Pedaços", style: const TextStyle(fontSize: 10)),
                        Text(
                          "${int.parse(e.saboreslimite) > 1 ? 'até ' : ''}${int.parse(e.saboreslimite)} ${int.parse(e.saboreslimite) > 1 ? 'sabores' : 'sabor'}",
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList()),
    );
  }
}
