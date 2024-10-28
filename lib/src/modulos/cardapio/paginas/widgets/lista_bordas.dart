import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class ListaBordas extends StatefulWidget {
  const ListaBordas({super.key});

  @override
  State<ListaBordas> createState() => _ListaBordasState();
}

class _ListaBordasState extends State<ListaBordas> {
  final provedor = Modular.get<ProvedorCardapio>();
  final provedorProduto = Modular.get<ProvedorProduto>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provedor,
      builder: (context, snapshot) {
        return ListenableBuilder(
          listenable: provedorProduto,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.only(left: 6.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(int.parse(provedor.configBigchef!.saborlimitedeborda), (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: FittedBox(
                        fit: BoxFit.fitWidth,
                        child: Badge(
                          label: (index + 1) == provedor.limiteSaborBordaSelecionado ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                          backgroundColor: Colors.green,
                          alignment: const Alignment(1, -1),
                          padding: const EdgeInsets.only(bottom: 2, top: 2),
                          smallSize: 0,
                          child: Container(
                            width: 180,
                            height: 70,
                            decoration: BoxDecoration(
                              border: Border.all(color: (index + 1) == provedor.limiteSaborBordaSelecionado ? Colors.green : Colors.grey),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: InkWell(
                              onTap: () {
                                ScaffoldMessenger.of(context).removeCurrentSnackBar();

                                if (provedor.limiteSaborBordaSelecionado == (index + 1)) {
                                  provedor.limiteSaborBordaSelecionado = 0;
                                  var listaF = provedorProduto.opcoesPacotesListaFinal;
                                  listaF.where((element) => element.id == 6).firstOrNull?.dados = [];

                                  provedorProduto.opcoesPacotesListaFinal = listaF;
                                } else {
                                  provedor.limiteSaborBordaSelecionado = (index + 1);
                                }

                                // print((widget.opcoesPacotesListaFinal.where((element) => element.id == 6).firstOrNull?.dados?.length ?? 0));

                                if ((provedorProduto.opcoesPacotesListaFinal.where((element) => element.id == 6).firstOrNull?.dados?.length ?? 0) > (index + 1)) {
                                  var listaF = provedorProduto.opcoesPacotesListaFinal;
                                  listaF.where((element) => element.id == 6).firstOrNull?.dados = [];

                                  provedorProduto.opcoesPacotesListaFinal = listaF;
                                }
                              },
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 65,
                                    height: 60,
                                    child: SfCircularChart(
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

                                              if ((index + 1) == provedor.limiteSaborBordaSelecionado &&
                                                  (index2 + 1) <= (provedorProduto.opcoesPacotesListaFinal.where((element) => element.id == 6).firstOrNull?.dados ?? []).length) {
                                                return {'x': '', 'y': 10, 'color': cores[index2 + 1]};
                                              }

                                              return {'x': '', 'y': 10, 'color': Colors.transparent};
                                            },
                                          ),
                                          explode: false,
                                          explodeIndex: 0,
                                          innerRadius: '60%',
                                          animationDuration: 0,
                                          cornerStyle: CornerStyle.bothCurve,
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
                                      Text(provedor.tamanhosPizza?.nomedotamanho ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                                      Text(
                                        "${index + 1 > 1 ? 'até ' : ''}${index + 1} ${index + 1 > 1 ? 'sabores' : 'sabor'}",
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
                  }),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
