import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_pedido_kit.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_editar_observacao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardCarrinho extends StatefulWidget {
  final Modelowordprodutos item;
  final String idComanda;

  final int index;
  final String idMesa;
  final dynamic value;
  final Function(bool increase) setarQuantidade;

  const CardCarrinho({
    super.key,
    required this.item,
    required this.index,
    required this.idComanda,
    required this.idMesa,
    required this.value,
    required this.setarQuantidade,
  });

  @override
  State<CardCarrinho> createState() => _CardCarrinhoState();
}

class _CardCarrinhoState extends State<CardCarrinho> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();

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
                                  // '${widget.item.nome}',
                                  // '${widgte.item.quantidade!.toStringAsFixed(0)}x ${widget.item.nome} ',
                                  widget.item.nome,
                                  maxLines: 1,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 30),
                              Text(
                                ((double.parse(widget.item.valorVenda)) * widget.item.quantidade!.toInt()).obterReal(),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                maxLines: 1,
                              ),
                            ],
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'Código: ${item.codigo}',
                              style: TextStyle(fontSize: 13),
                            ),
                            Spacer(),
                            Text(
                              item.tamanho != '' && item.tamanho != '0' ? item.tamanho : '',
                              style: TextStyle(fontSize: 13),
                            ),
                            // Text(item.tamanho != '' && item.tamanho != '0' ? item.tamanho : 'Sem tamanho'),
                            SizedBox(width: 25),
                          ],
                        ),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: GestureDetector(
                                  onTap: () {
                                    showModalBottomSheet(
                                      isScrollControlled: true,
                                      context: context,
                                      builder: (context) {
                                        return Padding(
                                          padding: MediaQuery.of(context).viewInsets,
                                          child: ModalEditarObservacao(
                                            index: widget.index,
                                            idProduto: widget.item.id,
                                            observacao: widget.item.observacao ?? '',
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  child: const Text(
                                    'Observação',
                                    style: TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: widget.item.quantidade! <= 1 ? const Icon(Icons.delete_outline_outlined) : const Icon(Icons.remove_circle_outline_outlined),
                                    onPressed: () {
                                      if (widget.item.quantidade! <= 1) {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return AlertDialog(
                                              title: const Text('Exclusão de Item'),
                                              content: const SingleChildScrollView(
                                                child: ListBody(
                                                  children: <Widget>[
                                                    Text('Deseja realmente excluir esse item?'),
                                                  ],
                                                ),
                                              ),
                                              actions: <Widget>[
                                                TextButton(
                                                  child: const Text('Cancelar'),
                                                  onPressed: () {
                                                    Navigator.of(context).pop();
                                                  },
                                                ),
                                                TextButton(
                                                  child: const Text('Excluir'),
                                                  onPressed: () async {
                                                    await carrinhoProvedor.excluirItemCarrinho(item.id, widget.index).then((sucesso) {
                                                      if (context.mounted) {
                                                        carrinhoProvedor.listarComandasPedidos();
                                                        Navigator.pop(context);
                                                      }

                                                      if (sucesso) return;

                                                      if (context.mounted) {
                                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                                          content: Text('Ocorreu um erro'),
                                                          showCloseIcon: true,
                                                        ));
                                                      }
                                                    });
                                                  },
                                                ),
                                              ],
                                            );
                                          },
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
                                      widget.item.quantidade!.toStringAsFixed(0),
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
                    if ((item.opcoesPacotesListaFinal ?? []).isNotEmpty) ...[
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
                if ((item.opcoesPacotesListaFinal ?? []).isNotEmpty) ...[
                  const Divider(height: 1),
                ],
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) {
                          return PaginaProduto(produto: item, editar: true, indexProduto: widget.index);
                        },
                      ));
                    },
                    child: Text('Editar Produto'),
                  ),
                ),
                ...(item.opcoesPacotesListaFinal ?? []).map((e) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.dados != null && e.dados!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 10),
                          child: Text(e.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
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
                                if (dado.quantimaximaselecao != null) ...[
                                  Text(
                                    '${dado.quantimaximaselecao != null ? '(${dado.quantimaximaselecao}) ' : ''}${dado.nome}',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ] else ...[
                                  Text(
                                    '${dado.quantidade != null ? '${dado.quantidade}x ' : ''}${dado.nome}',
                                    style: const TextStyle(fontSize: 15),
                                  ),
                                ],
                                Text(
                                  (double.parse(dado.valor ?? '0') * (dado.quantidade ?? 1)).obterReal(),
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else if (e.produtos != null && e.produtos!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 10),
                          child: Text(e.titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
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
