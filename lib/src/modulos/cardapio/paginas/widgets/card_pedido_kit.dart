import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class CardPedidoKit extends StatefulWidget {
  final ModeloProduto item;
  final bool somarValores;

  const CardPedidoKit({
    super.key,
    required this.item,
    required this.somarValores,
  });

  @override
  State<CardPedidoKit> createState() => _CardPedidoKitState();
}

class _CardPedidoKitState extends State<CardPedidoKit> with TickerProviderStateMixin {
  // control the state of the animation
  late final AnimationController _controller;

  // animation that generates value depending on tween applied
  late final Animation<double> _animation;

  // define the begin and the end value of an animation
  late final Tween<double> _sizeTween;

  // expansion state
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

  // toggle expandable without setState,
  // so that the widget does not rebuild itself.
  void _expandOnChanged() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  // dispose the controller to release it from the memory
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.item;

    // var soma = item.adicionais.fold(
    //   Modelowordadicionaisproduto(id: '', nome: '', valor: '0', quantidade: 0, foto: '', estaSelecionado: false, excluir: false),
    //   (previousValue, element) {
    //     return Modelowordadicionaisproduto(
    //       id: '',
    //       nome: '',
    //       valor: (double.parse(previousValue.valor) + (double.parse(element.valor) * element.quantidade)).toString(),
    //       quantidade: 0,
    //       foto: '',
    //       estaSelecionado: false,
    //       excluir: false,
    //     );
    //   },
    // );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 70,
            child: InkWell(
              onTap: () {
                _expandOnChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
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
                                  '${item.quantidade}x ${item.nome}',
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              Text(
                                // ((double.parse(item.valorVenda) + (widget.somarValores ? double.parse(soma.valor) : 0)) * item.quantidade!).obterReal(),
                                (double.parse(item.valorVenda) * item.quantidade!).obterReal(),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Text(item.tamanhos.isNotEmpty ? item.tamanhos.first.nome : ''),
                      ],
                    ),
                    Positioned(
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
                              ? const Icon(Icons.keyboard_arrow_up_outlined, key: ValueKey('icon2'))
                              : const Icon(Icons.keyboard_arrow_down_outlined, key: ValueKey('icon1')),
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
                ...(item.opcoesPacotes ?? []).map((e) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, top: 10),
                        child: Text(e.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                      if (e.dados != null) ...[
                        ListView.builder(
                          padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 5),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: e.dados!.length,
                          itemBuilder: (context, index) {
                            final dado = e.dados![index];

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${dado.quantidade != null ? '${dado.quantidade}x ' : ''}${dado.nome}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                Text(
                                  (double.parse(dado.valor ?? '0') * (dado.quantidade ?? 1)).obterReal(),
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else if (e.produtos != null) ...[
                        ListView.builder(
                          padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 5),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: e.produtos!.length,
                          itemBuilder: (context, index) {
                            final produto = e.produtos![index];

                            return CardPedidoKit(item: produto, somarValores: false);
                          },
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
