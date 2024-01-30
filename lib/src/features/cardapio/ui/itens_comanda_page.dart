import 'package:app/src/features/cardapio/interactor/cubit/categorias_cubit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ItensComandaPage extends StatefulWidget {
  final List<dynamic> listaComandosPedidos;
  const ItensComandaPage({super.key, required this.listaComandosPedidos});

  @override
  State<ItensComandaPage> createState() => _ItensComandaPageState();
}

class _ItensComandaPageState extends State<ItensComandaPage> {
  final CategoriasCubit _categoriasCubit = Modular.get<CategoriasCubit>();

  double precoTotal = 0;

  String precoTotalLabel = '';
  @override
  void initState() {
    super.initState();

    widget.listaComandosPedidos.map((e) {
      precoTotal += double.parse(e['valor']) * num.parse(e['quantidade']);
      precoTotalLabel = 'R\$ ${precoTotal.toStringAsFixed(2).replaceAll('.', ',')}';
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    double itemWidth = MediaQuery.of(context).size.width / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comanda'),
        centerTitle: true,
      ),
      bottomNavigationBar: Visibility(
        visible: true,
        child: Material(
          color: const Color.fromARGB(255, 61, 61, 61),
          child: InkWell(
            onTap: () {},
            child: SizedBox(
              height: kToolbarHeight,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: SizedBox(
                        width: itemWidth,
                        child: const Text(
                          'Total: ',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: itemWidth,
                    padding: const EdgeInsets.only(right: 30),
                    child: Text(precoTotalLabel,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.right),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.only(top: 10, left: 5, right: 5),
        child: widget.listaComandosPedidos.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100, child: Center(child: Text('Não há itens na Comanda'))),
                ],
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.listaComandosPedidos.length + 1,
                itemBuilder: (context, index) {
                  if (index == widget.listaComandosPedidos.length) {
                    return const SizedBox(height: 100, child: Center(child: Text('Fim da Lista')));
                  }

                  final item = widget.listaComandosPedidos[index];
                  return Card(
                    clipBehavior: Clip.hardEdge,
                    child: InkWell(
                      key: widget.key,
                      onTap: () async {},
                      borderRadius: BorderRadius.circular(5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: CachedNetworkImage(
                              width: 100,
                              height: 100,
                              fit: BoxFit.contain,
                              fadeOutDuration: const Duration(milliseconds: 100),
                              placeholder: (context, url) => const SizedBox(
                                height: 50.0,
                                width: 50.0,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                              imageUrl: item['foto'],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Padding(
                            padding: const EdgeInsets.all(0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width - 130,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        width: MediaQuery.of(context).size.width - 190,
                                        child: Text(
                                          '${item['nome']}',
                                          style: const TextStyle(
                                            fontSize: 17,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => Dialog(
                                              child: ListView(
                                                padding: const EdgeInsets.all(20),
                                                shrinkWrap: true,
                                                children: [
                                                  const Text(
                                                    'Deseja realmente excluir?',
                                                    style: TextStyle(fontSize: 20),
                                                  ),
                                                  const SizedBox(height: 15),
                                                  Expanded(
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.end,
                                                      children: [
                                                        TextButton(
                                                          onPressed: () {
                                                            Navigator.pop(context);
                                                          },
                                                          child: const Text('Carcelar'),
                                                        ),
                                                        const SizedBox(width: 10),
                                                        TextButton(
                                                          onPressed: () async {
                                                            final res = await _categoriasCubit.removerComandasPedidos(item['id']);

                                                            Navigator.pop(context);

                                                            if (res) {
                                                              setState(() {
                                                                widget.listaComandosPedidos.removeWhere((e) => e['id'] == item['id']);

                                                                precoTotal = 0;
                                                                widget.listaComandosPedidos.map((e) {
                                                                  precoTotal += double.parse(e['valor']) * num.parse(e['quantidade']);
                                                                }).toList();
                                                                precoTotalLabel = 'R\$ ${precoTotal.toStringAsFixed(2).replaceAll('.', ',')}';
                                                              });
                                                              return;
                                                            }

                                                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                              content: Text('Ocorreu um erro'),
                                                              showCloseIcon: true,
                                                            ));
                                                          },
                                                          child: const Text('excluir'),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: const SizedBox(
                                          width: 50,
                                          height: 40,
                                          child: Center(
                                            child: Icon(
                                              Icons.close,
                                              color: Colors.red,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Text(
                                  'Sem descrição',
                                  overflow: TextOverflow.fade,
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: Color.fromARGB(255, 111, 111, 111),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                SizedBox(
                                  width: MediaQuery.of(context).size.width - 140,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${double.parse(item['quantidade']).toStringAsFixed(0)} x R\$ ${item['valor'].replaceAll('.', ',')}',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      SizedBox(
                                        child: Align(
                                          alignment: Alignment.bottomRight,
                                          child: Text(
                                            'R\$ ${(double.parse(item['valor']) * num.parse(item['quantidade'])).toStringAsFixed(2).replaceAll('.', ',')}',
                                            style: const TextStyle(color: Colors.green, fontSize: 17),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
