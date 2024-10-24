import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

class TabCustom extends StatefulWidget {
  final String category;
  final ModeloCategoria categoria;
  final String? idComanda;
  final String? idComandaPedido;
  final String idMesa;
  final TipoCardapio tipo;
  const TabCustom({super.key, required this.category, required this.categoria, this.idComanda, this.idComandaPedido, required this.idMesa, required this.tipo});

  @override
  State<TabCustom> createState() => _TabCustomState();
}

class _TabCustomState extends State<TabCustom> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  ValueNotifier<bool> carregando = ValueNotifier(true);

  void listarProdutos(categoria) async {
    await provedorCardapio.listarProdutosPorCategoria(categoria);
    carregando.value = false;
  }

  void pesquisarProdutos(categoria) {
    listarProdutos(categoria);
  }

  @override
  void initState() {
    super.initState();
    listarProdutos(widget.category);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return RefreshIndicator(
      onRefresh: () async => listarProdutos(widget.category),
      child: ListenableBuilder(
        listenable: provedorCardapio,
        builder: (context, _) {
          return Column(
            children: [
              if (widget.categoria.tamanhosPizza != null && widget.categoria.tamanhosPizza!.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                      children: widget.categoria.tamanhosPizza!.map((e) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
                ),
              ],
              Expanded(
                child: ValueListenableBuilder(
                  valueListenable: carregando,
                  builder: (context, valueCarregando, _) {
                    return valueCarregando == true
                        ? const Center(child: CircularProgressIndicator())
                        : provedorCardapio.produtos.isEmpty && valueCarregando == false
                            ? ListView(
                                shrinkWrap: true,
                                children: const [SizedBox(height: 100, child: Center(child: Text('Não há Itens')))],
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: provedorCardapio.produtos.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == provedorCardapio.produtos.length) {
                                    return const SizedBox(height: 80, child: Center(child: Text('Fim da Lista')));
                                  }

                                  final item = provedorCardapio.produtos[index];

                                  return CardProduto(
                                    estaPesquisando: false,
                                    item: item,
                                    tipo: widget.tipo,
                                    idComandaPedido: widget.idComandaPedido!,
                                    idComanda: widget.idComanda!,
                                    idMesa: widget.idMesa,
                                  );
                                },
                              );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
