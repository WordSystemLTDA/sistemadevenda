import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/features/produto/interactor/state/produto_state.dart';
import 'package:app/src/shared/constantes/assets_constantes.dart';
import 'package:app/src/shared/utils/utils.dart';

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProdutoPage extends StatefulWidget {
  final ProdutoModel produto;
  final String tipo;
  final String idComanda;
  final String idMesa;
  const ProdutoPage({super.key, required this.produto, required this.tipo, required this.idComanda, required this.idMesa});

  @override
  State<ProdutoPage> createState() => _ProdutoPageState();
}

class _ProdutoPageState extends State<ProdutoPage> {
  final ItensComandaState stateItensComanda = ItensComandaState();
  final ProdutoState _produtoState = ProdutoState();

  bool isLoading = false;

  TextEditingController obsController = TextEditingController();

  double precoTotal = 0;
  int counter = 1;
  void updateCounter(bool isDecrement) {
    if (isDecrement) {
      if (counter == 1) return;
      precoTotal -= double.parse(widget.produto.valorVenda);
      setState(() => --counter);
    } else {
      precoTotal += double.parse(widget.produto.valorVenda);
      setState(() => counter++);
    }
  }

  void listarAdicionais() {
    _produtoState.listarAdicionais(widget.produto.id);
  }

  @override
  void initState() {
    super.initState();

    precoTotal = double.parse(widget.produto.valorVenda);
    listarAdicionais();
  }

  @override
  Widget build(BuildContext context) {
    final produto = widget.produto;
    final idComanda = widget.idComanda;
    final idMesa = widget.idMesa;

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);

        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text("${produto.nome} ${produto.tamanho}"),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            var comanda = idComanda.isEmpty ? 0 : idComanda;
            var mesa = idMesa.isEmpty ? 0 : idMesa;
            var valor = produto.valorVenda;
            var idProduto = produto.id;
            var observacaoMesa = '';
            var observacao = obsController.text;

            setState(() => isLoading = !isLoading);
            final res = await stateItensComanda.inserir(widget.tipo, mesa, comanda, valor, observacaoMesa, idProduto, counter, observacao);
            setState(() => isLoading = !isLoading);

            if (mounted && res) {
              Navigator.pop(context);
              return;
            }

            if (mounted) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Ocorreu um erro'),
                showCloseIcon: true,
              ));
            }
          },
          label: isLoading
              ? const CircularProgressIndicator()
              : Row(
                  children: [
                    const SizedBox(width: 10),
                    Text('R\$ ${precoTotal.toStringAsFixed(2).replaceAll('.', ',')}'),
                    const SizedBox(width: 10),
                    const Icon(Icons.check),
                    const SizedBox(width: 10),
                  ],
                ),
        ),
        body: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 2),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    produto.foto.isEmpty
                        ? Image.asset(Assets.boxAsset, width: 120, height: 120)
                        // ? Image.asset(Assets.produtoAsset, width: 120, height: 120)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: CachedNetworkImage(
                              width: 120,
                              height: 120,
                              fit: BoxFit.contain,
                              fadeOutDuration: const Duration(milliseconds: 100),
                              placeholder: (context, url) => const SizedBox(
                                height: 50.0,
                                width: 50.0,
                                child: Center(child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => const Icon(Icons.error),
                              imageUrl: produto.foto,
                            ),
                          ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => updateCounter(true),
                              icon: Icon(
                                Icons.remove_circle_outline,
                                size: 30,
                                color: counter == 1 ? Colors.grey : Colors.red,
                              ),
                            ),
                            Text(
                              counter.toString(),
                              style: const TextStyle(fontSize: 20),
                            ),
                            IconButton(
                              onPressed: () => updateCounter(false),
                              icon: const Icon(
                                Icons.add_circle_outline,
                                size: 30,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          "Preço",
                          style: TextStyle(fontSize: 18),
                        ),
                        Text(
                          Utils.coverterEmReal.format(double.parse(produto.valorVenda)),
                          style: const TextStyle(color: Colors.green, fontSize: 18),
                        ),
                        // Row(
                        //   children: [
                        //     const Text(
                        //       "Preço: ",
                        //       style: TextStyle(fontSize: 18),
                        //     ),
                        //     Text(
                        //       Utils.coverterEmReal.format(double.parse(produto.valorVenda)),
                        //       style: const TextStyle(color: Colors.green, fontSize: 18),
                        //     ),
                        //   ],
                        // ),
                        const Row(
                          children: [
                            Text(
                              "Total",
                              style: TextStyle(fontSize: 18),
                            ),
                            // Text(
                            //   Utils.coverterEmReal.format(precoTotal),
                            //   style: const TextStyle(color: Colors.green, fontSize: 18),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Observações: ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      Utils.coverterEmReal.format(precoTotal),
                      style: const TextStyle(color: Colors.green, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                TextField(
                  controller: obsController,
                  decoration: const InputDecoration(
                    alignLabelWithHint: true,
                    hintText: "Digite alguma Observação",
                    hintStyle: TextStyle(fontWeight: FontWeight.w300),
                    border: UnderlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                if (produto.descricao.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      produto.descricao,
                      overflow: TextOverflow.fade,
                      maxLines: 6,
                      style: const TextStyle(color: Color.fromARGB(255, 161, 161, 161)),
                    ),
                  ),
                ],
                ValueListenableBuilder(
                  valueListenable: listaAdicionais,
                  builder: (context, value, child) {
                    final somaAdicionaisSelecionadas = value.where((e) => e.estaSelecionado == true);

                    return Text(
                      'Adicionais (${somaAdicionaisSelecionadas.length})',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    );
                  },
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder(
                  valueListenable: listaAdicionais,
                  builder: (context, value, child) {
                    var precoTotalAdicional = 0.0;

                    return SizedBox(
                      height: MediaQuery.of(context).size.height - 450,
                      child: Expanded(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: value.length,
                          itemBuilder: (context, index) {
                            final item = value[index];

                            return SizedBox(
                              height: 70,
                              child: Card(
                                clipBehavior: Clip.hardEdge,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (listaAdicionais.value[index].estaSelecionado) {
                                        precoTotal -= double.parse(item.valor);
                                      } else {
                                        precoTotal += double.parse(item.valor);
                                      }
                                      listaAdicionais.value[index].estaSelecionado = !listaAdicionais.value[index].estaSelecionado;
                                    });
                                  },
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(8.0),
                                            child: CachedNetworkImage(
                                              width: 70,
                                              height: 70,
                                              fit: BoxFit.contain,
                                              fadeOutDuration: const Duration(milliseconds: 100),
                                              placeholder: (context, url) => const SizedBox(
                                                height: 70.0,
                                                width: 70.0,
                                                child: Center(child: CircularProgressIndicator()),
                                              ),
                                              errorWidget: (context, url, error) => const Icon(Icons.error),
                                              imageUrl: item.foto,
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            item.nome,
                                            style: const TextStyle(
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (value.firstWhere((element) => element.id == item.id).estaSelecionado) ...[
                                        Row(
                                          children: [
                                            IconButton(
                                              onPressed: () {
                                                if (item.quantidade > 1) {
                                                  setState(() {
                                                    --item.quantidade;
                                                    precoTotalAdicional -= double.parse(item.valor);
                                                    precoTotal -= double.parse(item.valor);
                                                  });
                                                }
                                              },
                                              icon: Icon(
                                                Icons.remove_circle_outline,
                                                size: 30,
                                                color: item.quantidade == 1 ? Colors.grey : Colors.red,
                                              ),
                                            ),
                                            Text(
                                              item.quantidade.toString(),
                                              style: const TextStyle(fontSize: 20),
                                            ),
                                            IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  item.quantidade++;
                                                  precoTotalAdicional += double.parse(item.valor);
                                                  precoTotal += double.parse(item.valor);
                                                });
                                              },
                                              icon: const Icon(
                                                Icons.add_circle_outline,
                                                size: 30,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ]
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                // Column(
                //   children: [
                //     Row(
                //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //       children: [
                //         const Text('Sub total', style: TextStyle(fontSize: 17)),
                //         Text(
                //           // 'R\$ ${widget.precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                //           'R\$ 100,00',
                //           style: const TextStyle(fontSize: 17, color: Colors.green),
                //         ),
                //       ],
                //     ),
                //     const SizedBox(height: 10),
                //     Row(
                //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //       children: [
                //         Row(
                //           children: [
                //             const Text('Total: ', style: TextStyle(fontSize: 17)),
                //             Text(
                //               // 'R\$ ${widget.precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                //               'R\$ 100,00',
                //               style: const TextStyle(fontSize: 17, color: Colors.green),
                //             ),
                //           ],
                //         ),
                //         SizedBox(
                //           // width: double.infinity,
                //           height: 50,
                //           child: OutlinedButton(
                //             style: ButtonStyle(
                //               backgroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.primary),
                //               side: const MaterialStatePropertyAll(BorderSide.none),
                //               shape: const MaterialStatePropertyAll(
                //                 RoundedRectangleBorder(
                //                   borderRadius: BorderRadius.all(Radius.circular(5)),
                //                 ),
                //               ),
                //             ),
                //             onPressed: () {},
                //             child: const Text('Concluir', style: TextStyle(color: Colors.white)),
                //           ),
                //         ),
                //       ],
                //     ),
                //     const SizedBox(height: 10),
                //   ],
                // ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
