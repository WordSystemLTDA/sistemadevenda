import 'package:app/src/features/cardapio/interactor/models/item_Comanda_modelo.dart';
import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:flutter/material.dart';

class CardItensVenda extends StatefulWidget {
  final ItemComandaModelo item;
  final String idComanda;
  final String idMesa;
  final dynamic value;
  final Function(bool increase) setarQuantidade;
  const CardItensVenda({
    super.key,
    required this.item,
    required this.idComanda,
    required this.idMesa,
    required this.value,
    required this.setarQuantidade,
  });

  @override
  State<CardItensVenda> createState() => _CardItensVendaState();
}

class _CardItensVendaState extends State<CardItensVenda> with TickerProviderStateMixin {
  final ItensComandaState state = ItensComandaState();

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Tween<double> _sizeTween;
  bool _isExpanded = false;

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

  void _expandOnChanged() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 100,
            child: InkWell(
              onTap: () {
                _expandOnChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Flexible(
                                  child: Text(
                                    '${widget.item.quantidade.toStringAsFixed(0)}x ${widget.item.nome} ',
                                    // item.nome,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 30),
                                Padding(
                                  padding: const EdgeInsets.only(right: 10),
                                  child: Text(
                                    'R\$ ${(widget.item.valor * widget.item.quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                TextButton(
                                  onPressed: () {},
                                  child: const Row(
                                    children: [
                                      Icon(Icons.edit, size: 18),
                                      SizedBox(width: 5),
                                      Text('Editar'),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: widget.item.quantidade <= 1
                                          ? const Icon(Icons.delete_outline_outlined)
                                          : const Icon(Icons.remove_circle_outline_outlined),
                                      onPressed: () {
                                        if (widget.item.quantidade <= 1) {
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
                                                            final res = await state.removerComandasPedidos(
                                                              widget.idComanda,
                                                              widget.idMesa,
                                                              [widget.item.id],
                                                            );

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
                                        } else {
                                          widget.setarQuantidade(false);
                                          // setState(() => --widget.item.quantidade);

                                          // double precoTotal = 0;
                                          // widget.value.listaComandosPedidos.map((e) {
                                          //   precoTotal += e.valor * e.quantidade;

                                          //   e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                                          // }).toList();

                                          // setState(() => widget.value.precoTotal = precoTotal);
                                        }
                                      },
                                    ),
                                    const SizedBox(width: 10),
                                    SizedBox(
                                      width: 30,
                                      child: Text(
                                        widget.item.quantidade.toStringAsFixed(0),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    IconButton(
                                      icon: const Icon(Icons.add_circle_outline_outlined),
                                      onPressed: () {
                                        widget.setarQuantidade(true);

                                        // setState(() => widget.item.quantidade++);

                                        // double precoTotal = 0;
                                        // widget.value.listaComandosPedidos.map((e) {
                                        //   precoTotal += e.valor * e.quantidade;

                                        //   e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                                        // }).toList();

                                        // setState(() => widget.value.precoTotal = precoTotal);
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 20,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        transitionBuilder: (child, anim) => RotationTransition(
                          turns: child.key == const ValueKey('icon1')
                              ? Tween<double>(begin: 0.75, end: 1).animate(anim)
                              : Tween<double>(begin: 1, end: 1).animate(anim),
                          child: ScaleTransition(scale: anim, child: child),
                        ),
                        child: _isExpanded
                            ? const Icon(Icons.keyboard_arrow_down_outlined, key: ValueKey('icon1'))
                            : const Icon(
                                Icons.keyboard_arrow_up_outlined,
                                key: ValueKey('icon2'),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizeTransition(
            sizeFactor: _sizeTween.animate(_animation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.item.listaAdicionais.isNotEmpty) ...[
                  const Divider(height: 1),
                  const Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child: Text('Adicionais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.all(10),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.item.listaAdicionais.length,
                    itemBuilder: (context, index) {
                      final adicional = widget.item.listaAdicionais[index];

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${adicional.quantidade}x ${adicional.nome}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            'R\$ ${(adicional.valorAdicional * adicional.quantidade).toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
