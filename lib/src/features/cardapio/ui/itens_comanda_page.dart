import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/card_itens_venda.dart';
import 'package:app/src/shared/constantes/assets_constantes.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ItensComandaPage extends StatefulWidget {
  final String idComanda;
  final String idMesa;
  const ItensComandaPage({super.key, required this.idComanda, required this.idMesa});

  @override
  State<ItensComandaPage> createState() => _ItensComandaPageState();
}

class _ItensComandaPageState extends State<ItensComandaPage> with TickerProviderStateMixin {
  final ItensComandaState state = ItensComandaState();
  bool isLoading = false;

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Tween<double> _sizeTween;
  // bool _isExpanded = false;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _sizeTween = Tween(begin: 0, end: 1);
    super.initState();
  }

  // void _expandOnChanged(item) {
  //   // setState(() {
  //   //   _isExpanded = !_isExpanded;
  //   // });
  //   setState(() => item.estaExpandido = !item.estaExpandido);

  //   // _isExpanded ? _controller.forward() : _controller.reverse();
  //   item.estaExpandido ? _controller.forward() : _controller.reverse();
  // }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double itemWidth = MediaQuery.of(context).size.width / 2;

    return ValueListenableBuilder(
      valueListenable: itensComandaState,
      builder: (context, value, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Comanda'),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (value.listaComandosPedidos.isNotEmpty) ...[
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        children: [
                          const Text(
                            'Deseja realmente excluir todos?',
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
                                    List<String> listaIdItemComanda = [];
                                    for (int index = 0; index < value.listaComandosPedidos.length; index++) {
                                      listaIdItemComanda.add(value.listaComandosPedidos[index].id);
                                    }

                                    final res = await state.removerComandasPedidos(widget.idComanda, widget.idMesa, listaIdItemComanda);

                                    if (mounted) {
                                      Navigator.pop(context);
                                    }

                                    if (res) return;

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                        content: Text('Ocorreu um erro'),
                                        showCloseIcon: true,
                                      ));
                                    }
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
                icon: const Icon(Icons.delete),
              ),
            ]
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: value.listaComandosPedidos.isEmpty
            ? null
            : FloatingActionButton.extended(
                onPressed: () async {
                  setState(() => isLoading = !isLoading);
                  final res = await state.lancarPedido(
                    widget.idMesa,
                    widget.idComanda,
                    value.precoTotal,
                    value.quantidadeTotal,
                    '',
                    [...value.listaComandosPedidos.map((e) => e.id)],
                  );
                  setState(() => isLoading = !isLoading);

                  if (mounted && res) {
                    Modular.to.pushNamed('/comandas');
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
                    : const Row(
                        children: [
                          Text('Finalizar'),
                          SizedBox(width: 10),
                          Icon(Icons.check),
                        ],
                      ),
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
                      // child: Text('R\$ ${value.precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
                      child: Text('R\$ ${value.precoTotal.toStringAsFixed(2).replaceAll('.', ',')}',
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
          child: value.listaComandosPedidos.isEmpty
              ? ListView(
                  children: const [
                    SizedBox(height: 100, child: Center(child: Text('Não há itens na Comanda'))),
                  ],
                )
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: value.listaComandosPedidos.length + 1,
                  itemBuilder: (context, index) {
                    if (index == value.listaComandosPedidos.length) {
                      return const SizedBox(height: 100, child: Center(child: Text('Fim da Lista')));
                    }

                    final item = value.listaComandosPedidos[index];

                    return CardItensVenda(
                      item: item,
                      idComanda: widget.idComanda,
                      idMesa: widget.idMesa,
                      value: value,
                      setarQuantidade: (increase) {
                        if (increase) {
                          setState(() => item.quantidade++);

                          double precoTotal = 0;
                          value.listaComandosPedidos.map((e) {
                            precoTotal += e.valor * e.quantidade;

                            e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                          }).toList();

                          setState(() => value.precoTotal = precoTotal);
                        } else {
                          setState(() => --item.quantidade);

                          double precoTotal = 0;
                          value.listaComandosPedidos.map((e) {
                            precoTotal += e.valor * e.quantidade;

                            e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                          }).toList();

                          setState(() => value.precoTotal = precoTotal);
                        }
                      },
                    );

                    // return Card(
                    //   shape: RoundedRectangleBorder(
                    //     borderRadius: BorderRadius.circular(5),
                    //   ),
                    //   child: Column(
                    //     crossAxisAlignment: CrossAxisAlignment.start,
                    //     children: [
                    //       SizedBox(
                    //         height: 100,
                    //         child: InkWell(
                    //           onTap: () {
                    //             _expandOnChanged();
                    //           },
                    //           child: Padding(
                    //             padding: const EdgeInsets.all(10.0),
                    //             child: Row(
                    //               children: [
                    //                 Expanded(
                    //                   child: Column(
                    //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //                     children: [
                    //                       Expanded(
                    //                         child: Row(
                    //                           crossAxisAlignment: CrossAxisAlignment.start,
                    //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //                           children: [
                    //                             Flexible(
                    //                               child: Text(
                    //                                 '${item.quantidade.toStringAsFixed(0)}x ${item.nome} ',
                    //                                 // item.nome,
                    //                                 maxLines: 1,
                    //                                 style: const TextStyle(
                    //                                   fontSize: 18,
                    //                                   fontWeight: FontWeight.w500,
                    //                                   overflow: TextOverflow.ellipsis,
                    //                                 ),
                    //                               ),
                    //                             ),
                    //                             const SizedBox(width: 30),
                    //                             Padding(
                    //                               padding: const EdgeInsets.only(right: 10),
                    //                               child: Text(
                    //                                 'R\$ ${(item.valor * item.quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                    //                                 style: TextStyle(
                    //                                   fontSize: 20,
                    //                                   fontWeight: FontWeight.w500,
                    //                                   color: Theme.of(context).colorScheme.primary,
                    //                                 ),
                    //                                 maxLines: 1,
                    //                               ),
                    //                             ),
                    //                           ],
                    //                         ),
                    //                       ),
                    //                       Expanded(
                    //                         child: Row(
                    //                           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //                           children: [
                    //                             TextButton(
                    //                               onPressed: () {},
                    //                               child: const Row(
                    //                                 children: [
                    //                                   Icon(Icons.edit, size: 18),
                    //                                   SizedBox(width: 5),
                    //                                   Text('Editar'),
                    //                                 ],
                    //                               ),
                    //                             ),
                    //                             Row(
                    //                               children: [
                    //                                 IconButton(
                    //                                   icon: item.quantidade <= 1
                    //                                       ? const Icon(Icons.delete_outline_outlined)
                    //                                       : const Icon(Icons.remove_circle_outline_outlined),
                    //                                   onPressed: () {
                    //                                     if (item.quantidade <= 1) {
                    //                                       showDialog(
                    //                                         context: context,
                    //                                         builder: (context) => Dialog(
                    //                                           child: ListView(
                    //                                             padding: const EdgeInsets.all(20),
                    //                                             shrinkWrap: true,
                    //                                             children: [
                    //                                               const Text(
                    //                                                 'Deseja realmente excluir?',
                    //                                                 style: TextStyle(fontSize: 20),
                    //                                               ),
                    //                                               const SizedBox(height: 15),
                    //                                               Expanded(
                    //                                                 child: Row(
                    //                                                   mainAxisAlignment: MainAxisAlignment.end,
                    //                                                   children: [
                    //                                                     TextButton(
                    //                                                       onPressed: () {
                    //                                                         Navigator.pop(context);
                    //                                                       },
                    //                                                       child: const Text('Carcelar'),
                    //                                                     ),
                    //                                                     const SizedBox(width: 10),
                    //                                                     TextButton(
                    //                                                       onPressed: () async {
                    //                                                         final res = await state.removerComandasPedidos(
                    //                                                           widget.idComanda,
                    //                                                           widget.idMesa,
                    //                                                           [item.id],
                    //                                                         );

                    //                                                         if (mounted) {
                    //                                                           Navigator.pop(context);
                    //                                                         }

                    //                                                         if (res) return;

                    //                                                         if (mounted) {
                    //                                                           ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    //                                                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    //                                                             content: Text('Ocorreu um erro'),
                    //                                                             showCloseIcon: true,
                    //                                                           ));
                    //                                                         }
                    //                                                       },
                    //                                                       child: const Text('excluir'),
                    //                                                     ),
                    //                                                   ],
                    //                                                 ),
                    //                                               ),
                    //                                             ],
                    //                                           ),
                    //                                         ),
                    //                                       );
                    //                                     } else {
                    //                                       setState(() => --item.quantidade);

                    //                                       double precoTotal = 0;
                    //                                       value.listaComandosPedidos.map((e) {
                    //                                         precoTotal += e.valor * e.quantidade;

                    //                                         e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                    //                                       }).toList();

                    //                                       setState(() => value.precoTotal = precoTotal);
                    //                                     }
                    //                                   },
                    //                                 ),
                    //                                 const SizedBox(width: 10),
                    //                                 SizedBox(
                    //                                   width: 30,
                    //                                   child: Text(
                    //                                     item.quantidade.toStringAsFixed(0),
                    //                                     textAlign: TextAlign.center,
                    //                                     style: const TextStyle(fontSize: 16),
                    //                                   ),
                    //                                 ),
                    //                                 const SizedBox(width: 10),
                    //                                 IconButton(
                    //                                   icon: const Icon(Icons.add_circle_outline_outlined),
                    //                                   onPressed: () {
                    //                                     setState(() => item.quantidade++);

                    //                                     double precoTotal = 0;
                    //                                     value.listaComandosPedidos.map((e) {
                    //                                       precoTotal += e.valor * e.quantidade;

                    //                                       e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                    //                                     }).toList();

                    //                                     setState(() => value.precoTotal = precoTotal);
                    //                                   },
                    //                                 ),
                    //                               ],
                    //                             ),
                    //                           ],
                    //                         ),
                    //                       ),
                    //                     ],
                    //                   ),
                    //                 ),
                    //                 SizedBox(
                    //                   width: 20,
                    //                   child: AnimatedSwitcher(
                    //                     duration: const Duration(milliseconds: 200),
                    //                     transitionBuilder: (child, anim) => RotationTransition(
                    //                       turns: child.key == const ValueKey('icon1')
                    //                           ? Tween<double>(begin: 0.75, end: 1).animate(anim)
                    //                           : Tween<double>(begin: 1, end: 1).animate(anim),
                    //                       child: ScaleTransition(scale: anim, child: child),
                    //                     ),
                    //                     // child: _isExpanded
                    //                     child: item.estaExpandido
                    //                         ? const Icon(Icons.keyboard_arrow_down_outlined, key: ValueKey('icon1'))
                    //                         : const Icon(
                    //                             Icons.keyboard_arrow_up_outlined,
                    //                             key: ValueKey('icon2'),
                    //                           ),
                    //                   ),
                    //                 ),
                    //               ],
                    //             ),
                    //           ),
                    //         ),
                    //       ),
                    //       SizeTransition(
                    //         sizeFactor: _sizeTween.animate(_animation),
                    //         child: Column(
                    //           crossAxisAlignment: CrossAxisAlignment.start,
                    //           children: [
                    //             if (item.listaAdicionais.isNotEmpty) ...[
                    //               const Divider(height: 1),
                    //               const Padding(
                    //                 padding: EdgeInsets.only(left: 10, top: 10),
                    //                 child: Text('Adicionais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    //               ),
                    //               ListView.builder(
                    //                 padding: const EdgeInsets.all(10),
                    //                 shrinkWrap: true,
                    //                 physics: const NeverScrollableScrollPhysics(),
                    //                 itemCount: item.listaAdicionais.length,
                    //                 itemBuilder: (context, index) {
                    //                   final adicional = item.listaAdicionais[index];

                    //                   return Row(
                    //                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //                     children: [
                    //                       Text(
                    //                         '${adicional.quantidade}x ${adicional.nome}',
                    //                         style: const TextStyle(fontSize: 15),
                    //                       ),
                    //                       Text(
                    //                         'R\$ ${(adicional.valorAdicional * adicional.quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                    //                         style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                    //                       ),
                    //                     ],
                    //                   );
                    //                 },
                    //               ),
                    //             ],
                    //           ],
                    //         ),
                    //       ),
                    //     ],
                    //   ),
                    // );
                  },
                ),
        ),
      ),
    );
  }
}
