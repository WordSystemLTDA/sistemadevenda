import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:app/src/features/cardapio/ui/widgets/card_itens_venda.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinho extends StatefulWidget {
  final String idComanda;
  final String idMesa;
  const PaginaCarrinho({super.key, required this.idComanda, required this.idMesa});

  @override
  State<PaginaCarrinho> createState() => _PaginaCarrinhoState();
}

class _PaginaCarrinhoState extends State<PaginaCarrinho> with TickerProviderStateMixin {
  final ItensComandaState state = ItensComandaState();
  bool isLoading = false;

  late final AnimationController _controller;
  // late final Animation<double> _animation;
  // late final Tween<double> _sizeTween;
  // bool _isExpanded = false;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    // _animation = CurvedAnimation(
    //   parent: _controller,
    //   curve: Curves.fastOutSlowIn,
    // );
    // _sizeTween = Tween(begin: 0, end: 1);
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
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () async {
                                    List<String> listaIdItemComanda = [];
                                    for (int index = 0; index < value.listaComandosPedidos.length; index++) {
                                      listaIdItemComanda.add(value.listaComandosPedidos[index].id);
                                    }

                                    await state.removerComandasPedidos(widget.idComanda, widget.idMesa, listaIdItemComanda).then((sucesso) {
                                      if (mounted) {
                                        Navigator.pop(context);
                                      }

                                      if (sucesso) return;

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text('Ocorreu um erro'),
                                          showCloseIcon: true,
                                        ));
                                      }
                                    });
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

                  await state.lancarPedido(
                    widget.idMesa,
                    widget.idComanda,
                    value.precoTotal,
                    value.quantidadeTotal,
                    '',
                    [...value.listaComandosPedidos.map((e) => e.id)],
                  ).then((sucesso) {
                    if (sucesso) {
                      if (mounted) {
                        if (widget.idComanda != '0') {
                          Modular.to.pushReplacementNamed('/comandas');
                        } else if (widget.idMesa != '0') {
                          Modular.to.pushReplacementNamed('/mesas');
                        }
                      }
                      return;
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Ocorreu um erro'),
                        showCloseIcon: true,
                      ));
                    }
                  }).whenComplete(() {
                    setState(() => isLoading = !isLoading);
                  });
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
                  itemCount: value.listaComandosPedidos.length,
                  itemBuilder: (context, index) {
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
                  },
                ),
        ),
      ),
    );
  }
}
