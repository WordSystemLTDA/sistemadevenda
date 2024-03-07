import 'package:app/src/features/cardapio/interactor/models/adicional_modelo.dart';
import 'package:app/src/features/cardapio/interactor/models/item_Comanda_modelo.dart';
import 'package:app/src/features/cardapio/interactor/states/itens_comanda_state.dart';
import 'package:brasil_fields/brasil_fields.dart';
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
    var item = widget.item;

    var soma = item.listaAdicionais.fold(
      AdicionalModelo(id: '', nome: '', valorAdicional: 0, quantidade: 0),
      (previousValue, element) {
        return AdicionalModelo(
          id: '',
          nome: '',
          valorAdicional: (previousValue.valorAdicional + (element.valorAdicional * element.quantidade)),
          quantidade: 0,
        );
      },
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 115,
            child: InkWell(
              onTap: () {
                _expandOnChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                              Text(
                                ((widget.item.valor + soma.valorAdicional) * widget.item.quantidade).obterReal(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Text(item.tamanhoSelecionado),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: GestureDetector(
                                  onTap: () {},
                                  child: const Text(
                                    'Editar',
                                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: widget.item.quantidade <= 1 ? const Icon(Icons.delete_outline_outlined) : const Icon(Icons.remove_circle_outline_outlined),
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
                                                          await state.removerComandasPedidos(
                                                            widget.idComanda,
                                                            widget.idMesa,
                                                            [widget.item.id],
                                                          ).then((sucesso) {
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
                                      } else {
                                        widget.setarQuantidade(false);
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
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox(
                        width: 20,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, anim) => RotationTransition(
                            turns: child.key == const ValueKey('icon1') ? Tween<double>(begin: 0.75, end: 1).animate(anim) : Tween<double>(begin: 1, end: 1).animate(anim),
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
                const Divider(height: 1),
                if (item.tamanhoSelecionado != '') ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child: Text('Tamanho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 10.0, top: 5, right: 10, bottom: 10),
                    child: Text(item.tamanhoSelecionado),
                  )
                ],
                if (item.listaAcompanhamentos.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 10, top: 10),
                    child: Text('Acompanhamentos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 10),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: item.listaAcompanhamentos.length,
                    itemBuilder: (context, index) {
                      final adicional = item.listaAcompanhamentos[index];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            adicional.nome,
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            double.parse(adicional.valor) == 0 ? 'Grátis' : double.parse(adicional.valor).toString(),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                if (item.listaAdicionais.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 10, top: 0),
                    child: Text('Adicionais', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  ListView.builder(
                    padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 10),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: item.listaAdicionais.length,
                    itemBuilder: (context, index) {
                      final adicional = item.listaAdicionais[index];
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${adicional.quantidade}x ${adicional.nome}',
                            style: const TextStyle(fontSize: 15),
                          ),
                          Text(
                            (adicional.valorAdicional * adicional.quantidade).obterReal(),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                Padding(
                  padding: EdgeInsets.only(left: 10, top: item.listaAdicionais.isEmpty ? 10 : 0),
                  child: const Text('Valores', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Produto'),
                          Text(
                            "${item.quantidade > 1 ? '${item.quantidade}x de' : ''} ${item.valor.obterReal()}",
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                          ),
                        ],
                      ),
                      if (soma.valorAdicional > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Adicionais'),
                            Text(
                              "${item.quantidade > 1 && soma.valorAdicional > 0 ? '${item.quantidade}x de' : ''} ${soma.valorAdicional.obterReal()}",
                              style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                            ),
                          ],
                        ),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total'),
                          Text(
                            ((item.valor + soma.valorAdicional) * item.quantidade).obterReal(),
                            style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
