import 'dart:async';

import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_pedido_kit.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardProdutoAcompanhar extends StatefulWidget {
  final Modelowordprodutos item;
  final Modeloworddadoscardapio? dados;
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;
  final dynamic value;
  final TipoCardapio tipo;
  final Function(bool increase) setarQuantidade;

  const CardProdutoAcompanhar({
    super.key,
    required this.item,
    required this.dados,
    required this.idComanda,
    required this.idComandaPedido,
    required this.idMesa,
    required this.value,
    required this.setarQuantidade,
    required this.tipo,
  });

  @override
  State<CardProdutoAcompanhar> createState() => _CardProdutoAcompanharState();
}

class _CardProdutoAcompanharState extends State<CardProdutoAcompanhar> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Tween<double> _sizeTween;
  bool _isExpanded = false;

  Timer? _tickerTempoLancado;
  // antiga animação card produto
  StreamController<String> tempoLancadoController = StreamController<String>();

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
    _updateTimer();
    _tickerTempoLancado ??= Timer.periodic(const Duration(seconds: 1), (_) => _updateTimer());
    super.initState();
  }

  void _updateTimer() {
    if (widget.item.dataLancado != null) {
      final duration = DateTime.now().difference(DateTime.parse(widget.item.dataLancado!));
      final newDuration = ConfigSistema.formatarHora(duration);

      tempoLancadoController.add(newDuration);
    }
  }

  void _expandOnChanged() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    if (_tickerTempoLancado != null) {
      _tickerTempoLancado!.cancel();
      tempoLancadoController.close();
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.item;

    // var soma = item.adicionais.fold(
    //   Modelowordadicionaisproduto(id: 'id', nome: 'nome', valor: '0', foto: 'foto', quantidade: 1, estaSelecionado: false, excluir: false),
    //   (previousValue, element) {
    //     return Modelowordadicionaisproduto(
    //       id: '',
    //       nome: '',
    //       valor: (double.parse(previousValue.valor) + (double.parse(element.valor) * element.quantidade)).toStringAsFixed(2),
    //       quantidade: 1,
    //       estaSelecionado: false,
    //       excluir: false,
    //       foto: '',
    //     );
    //   },
    // );
    // var somaAcompanhamentos = item.acompanhamentos.fold(
    //   Modelowordacompanhamentosproduto(id: 'id', nome: 'nome', valor: '0', foto: 'foto', estaSelecionado: false, excluir: false),
    //   (previousValue, element) {
    //     return Modelowordacompanhamentosproduto(
    //       id: '',
    //       nome: '',
    //       valor: (double.parse(previousValue.valor) + (double.parse(element.valor))).toStringAsFixed(2),
    //       estaSelecionado: false,
    //       excluir: false,
    //       foto: '',
    //     );
    //   },
    // );

    // var somaCortesias = item.cortesias.fold(
    //   Modelowordcortesiasproduto(id: 'id', nome: 'nome', valor: '0', foto: 'foto', estaSelecionado: false, excluir: false, quantimaximaselecao: ''),
    //   (previousValue, element) {
    //     return Modelowordcortesiasproduto(
    //       id: '',
    //       nome: '',
    //       quantimaximaselecao: '',
    //       valor: (double.parse(previousValue.valor) + (double.parse(element.valor))).toStringAsFixed(2),
    //       estaSelecionado: false,
    //       excluir: false,
    //       foto: '',
    //     );
    //   },
    // );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(5),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 105,
            child: InkWell(
              onTap: () {
                _expandOnChanged();
              },
              child: Padding(
                padding: const EdgeInsets.all(7.0),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(height: 5),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '${widget.item.nome} ',
                                // '${widget.item.quantidade!.toStringAsFixed(0)}x ${widget.item.nome} ',
                                // item.nome,
                                maxLines: 1,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 30),
                            Row(
                              children: [
                                Text(
                                  ((double.parse(widget.item.valorVenda)) * widget.item.quantidade!.toInt()).obterReal(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  maxLines: 1,
                                ),
                                const SizedBox(width: 5),
                              ],
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Row(
                          children: [
                            Text("Código: ${item.codigo}"),
                            Spacer(),
                            const Text("Quant.:  ", style: TextStyle(fontSize: 13)),
                            Text(widget.item.quantidade!.toStringAsFixed(0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                            SizedBox(width: 5),
                          ],
                        ),
                        SizedBox(height: 10),
                        StreamBuilder<String>(
                          stream: tempoLancadoController.stream,
                          initialData: 'Carregando',
                          builder: (context, snapshot) {
                            return Text("Item lançado há: ${snapshot.data!}", style: const TextStyle(fontSize: 13));
                          },
                        ),
                        // Row(
                        //   children: [
                        //     const Text("Quantidade:  ", style: TextStyle(fontSize: 13)),
                        //     Text(widget.item.quantidade!.toStringAsFixed(0), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        //   ],
                        // ),
                        if (item.tamanho != '' && item.tamanho != '0') Text(item.tamanho),
                        Padding(
                          padding: const EdgeInsets.only(top: 0.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (item.destinoDeImpressao != null && item.destinoDeImpressao!.nome.isNotEmpty) ...[
                                // IconButton(
                                //   onPressed: () {
                                //     if (widget.dados != null) {
                                //       final duration = DateTime.now().difference(DateTime.parse(widget.dados!.dataAbertura!));
                                //       final newDuration = ConfigSistema.formatarHora(duration);

                                //       Impressao.comprovanteDeConsumo(
                                //         // tipoImpressao: '2',
                                //         // tipo: widget.tipo,
                                //         // comanda: widget.dados!.nome!,
                                //         numeroPedido: widget.dados!.numeroPedido!,
                                //         // nomeCliente: widget.dados!.nomeCliente!,
                                //         nomeEmpresa: widget.dados!.nomeEmpresa!,
                                //         produtos: [item],
                                //         celularEmpresa: widget.dados!.celularEmpresa ?? '',
                                //         cnpjEmpresa: widget.dados!.cnpjEmpresa ?? '',
                                //         enderecoEmpresa: widget.dados!.enderecoEmpresa ?? '',
                                //         local: '',
                                //         nomelancamento: widget.dados!.nomelancamento ?? [],
                                //         permanencia: newDuration,
                                //         somaValorHistorico: widget.dados!.somaValorHistorico ?? '',
                                //         tipodeentrega: widget.dados!.tipodeentrega ?? '',
                                //         total: widget.dados!.valorTotal ?? '',
                                //         valorentrega: widget.dados!.valorentrega ?? '',
                                //         nomeCliente: (widget.dados!.nomeCliente == '' ? null : widget.dados!.nomeCliente) ?? 'Sem Cliente',
                                //       );
                                //     }
                                //   },
                                //   icon: const Icon(Icons.print_rounded),
                                // ),
                              ] else ...[
                                const SizedBox(),
                              ],
                              Row(
                                children: [
                                  // IconButton(
                                  //   icon: widget.item.quantidade! <= 1 ? const Icon(Icons.delete_outline_outlined) : const Icon(Icons.remove_circle_outline_outlined),
                                  //   onPressed: () {
                                  //     if (widget.item.quantidade! <= 1) {
                                  //       showDialog(
                                  //         context: context,
                                  //         builder: (context) {
                                  //           return AlertDialog(
                                  //             title: const Text('Excluir produto'),
                                  //             content: const SingleChildScrollView(
                                  //               child: ListBody(
                                  //                 children: <Widget>[
                                  //                   Text('Deseja realmente excluir esse item?'),
                                  //                 ],
                                  //               ),
                                  //             ),
                                  //             actions: <Widget>[
                                  //               TextButton(
                                  //                 child: const Text('Cancelar'),
                                  //                 onPressed: () {
                                  //                   Navigator.of(context).pop();
                                  //                 },
                                  //               ),
                                  //               TextButton(
                                  //                 child: const Text('Excluir'),
                                  //                 onPressed: () async {
                                  //                   await carrinhoProvedor.removerComandasPedidos().then((sucesso) {
                                  //                     if (context.mounted) {
                                  //                       carrinhoProvedor.listarComandasPedidos();
                                  //                       Navigator.pop(context);
                                  //                     }

                                  //                     if (sucesso) return;

                                  //                     if (context.mounted) {
                                  //                       ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                  //                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  //                         content: Text('Ocorreu um erro'),
                                  //                         showCloseIcon: true,
                                  //                       ));
                                  //                     }
                                  //                   });
                                  //                 },
                                  //               ),
                                  //             ],
                                  //           );
                                  //         },
                                  //       );
                                  //     } else {
                                  //       widget.setarQuantidade(false);
                                  //     }
                                  //   },
                                  // ),
                                  //
                                  //
                                  //
                                  //
                                  //
                                  // const SizedBox(width: 10),
                                  // SizedBox(
                                  //   width: 30,
                                  //   child: Text(
                                  //     widget.item.quantidade!.toStringAsFixed(0),
                                  //     textAlign: TextAlign.center,
                                  //     style: const TextStyle(fontSize: 14),
                                  //   ),
                                  // ),
                                  // const SizedBox(width: 60),
                                  //
                                  //
                                  //
                                  //
                                  //
                                  // IconButton(
                                  //   icon: const Icon(Icons.add_circle_outline_outlined),
                                  //   onPressed: () {
                                  //     widget.setarQuantidade(true);
                                  //   },
                                  // ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((item.opcoesPacotesListaFinal ?? []).isNotEmpty) ...[
                      Positioned(
                        top: 64,
                        right: 5,
                        // bottom: 0,
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
                ...(item.opcoesPacotesListaFinal ?? []).map((e) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.dados != null && e.dados!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 10),
                          child: Text(e.titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                                ),
                              ],
                            );
                          },
                        ),
                      ] else if (e.produtos != null && e.produtos!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 10),
                          child: Text(e.titulo, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
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
                //   if (item.cortesias.isNotEmpty) ...[
                //     const Padding(
                //       padding: EdgeInsets.only(left: 10, top: 10),
                //       child: Text('Cortesias', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //     ),
                //     ListView.builder(
                //       padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 0),
                //       shrinkWrap: true,
                //       physics: const NeverScrollableScrollPhysics(),
                //       itemCount: item.cortesias.length,
                //       itemBuilder: (context, index) {
                //         final cortesia = item.cortesias[index];
                //         return Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //           children: [
                //             Text(
                //               cortesia.nome,
                //               style: const TextStyle(fontSize: 15),
                //             ),
                //             Text(
                //               double.parse(cortesia.valor) == 0 ? 'Grátis' : double.parse(cortesia.valor).obterReal(),
                //               style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //             ),
                //           ],
                //         );
                //       },
                //     ),
                //   ],
                //   if (item.tamanhos.isNotEmpty) ...[
                //     const Padding(
                //       padding: EdgeInsets.only(left: 10, top: 10),
                //       child: Text('Tamanho', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //     ),
                //     Padding(
                //       padding: const EdgeInsets.only(left: 10.0, top: 5, right: 10, bottom: 0),
                //       child: Row(
                //         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //         children: [
                //           Text(item.tamanhos.first.nome),
                //           Text(
                //             double.parse(item.tamanhos.first.valor).obterReal(),
                //             style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //           ),
                //         ],
                //       ),
                //     )
                //   ],
                //   if (item.kits.isNotEmpty) ...[
                //     const Padding(
                //       padding: EdgeInsets.only(left: 10, top: 10),
                //       child: Text('Combo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //     ),
                //     ListView.builder(
                //       padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 0),
                //       shrinkWrap: true,
                //       physics: const NeverScrollableScrollPhysics(),
                //       itemCount: item.kits.length,
                //       itemBuilder: (context, index) {
                //         final kit = item.kits[index];

                //         return CardPedidoKit(item: kit, somarValores: false);
                //       },
                //     ),
                //   ],
                //   if (item.acompanhamentos.isNotEmpty) ...[
                //     const Padding(
                //       padding: EdgeInsets.only(left: 10, top: 10),
                //       child: Text('Acompanhamentos', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //     ),
                //     ListView.builder(
                //       padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 0),
                //       shrinkWrap: true,
                //       physics: const NeverScrollableScrollPhysics(),
                //       itemCount: item.acompanhamentos.length,
                //       itemBuilder: (context, index) {
                //         final adicional = item.acompanhamentos[index];
                //         return Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //           children: [
                //             Text(
                //               adicional.nome,
                //               style: const TextStyle(fontSize: 15),
                //             ),
                //             Text(
                //               double.parse(adicional.valor) == 0 ? 'Grátis' : double.parse(adicional.valor).obterReal(),
                //               style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //             ),
                //           ],
                //         );
                //       },
                //     ),
                //   ],
                //   if (item.adicionais.isNotEmpty) ...[
                //     const Padding(
                //       padding: EdgeInsets.only(left: 10, top: 10),
                //       child: Text('Adicionais', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //     ),
                //     ListView.builder(
                //       padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 0),
                //       shrinkWrap: true,
                //       physics: const NeverScrollableScrollPhysics(),
                //       itemCount: item.adicionais.length,
                //       itemBuilder: (context, index) {
                //         final adicional = item.adicionais[index];
                //         return Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //           children: [
                //             Text(
                //               '${adicional.quantidade}x ${adicional.nome}',
                //               style: const TextStyle(fontSize: 15),
                //             ),
                //             Text(
                //               (double.parse(adicional.valor) * adicional.quantidade).obterReal(),
                //               style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //             ),
                //           ],
                //         );
                //       },
                //     ),
                //   ],
                //   if (item.itensRetiradas.isNotEmpty) ...[
                //     const Padding(
                //       padding: EdgeInsets.only(left: 10, top: 10),
                //       child: Text('Itens Retiradas', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //     ),
                //     ListView.builder(
                //       padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 0),
                //       shrinkWrap: true,
                //       physics: const NeverScrollableScrollPhysics(),
                //       itemCount: item.itensRetiradas.length,
                //       itemBuilder: (context, index) {
                //         final itemRetirada = item.itensRetiradas[index];

                //         return Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //           children: [
                //             Text(itemRetirada.nome, style: const TextStyle(fontSize: 15)),
                //           ],
                //         );
                //       },
                //     ),
                //   ],
                //   const Padding(
                //     padding: EdgeInsets.only(left: 10, top: 10),
                //     child: Text('Valores', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                //   ),
                //   Padding(
                //     padding: const EdgeInsets.only(left: 10, top: 5, right: 10, bottom: 10),
                //     child: Column(
                //       children: [
                //         Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //           children: [
                //             const Text('Produto'),
                //             Text(
                //               "${item.quantidade! > 1 ? '${item.quantidade}x de' : ''} ${(double.parse(item.valorVenda) - double.parse(soma.valor) - double.parse(somaAcompanhamentos.valor) - double.parse(somaCortesias.valor)).obterReal()}",
                //               style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //             ),
                //           ],
                //         ),
                //         if (item.cortesias.isNotEmpty) ...[
                //           Row(
                //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //             children: [
                //               const Text('Cortesias'),
                //               Text(
                //                 double.parse(somaCortesias.valor).obterReal(),
                //                 style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //               ),
                //             ],
                //           ),
                //         ],
                //         if (item.adicionais.isNotEmpty) ...[
                //           Row(
                //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //             children: [
                //               const Text('Adicionais'),
                //               Text(
                //                 "${item.quantidade! > 1 && double.parse(soma.valor) > 0 ? '${item.quantidade}x de' : ''} ${double.parse(soma.valor).obterReal()}",
                //                 style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //               ),
                //             ],
                //           ),
                //         ],
                //         if (item.acompanhamentos.isNotEmpty) ...[
                //           Row(
                //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //             children: [
                //               const Text('Acompanhamentos'),
                //               Text(
                //                 double.parse(somaAcompanhamentos.valor).obterReal(),
                //                 style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //               ),
                //             ],
                //           ),
                //         ],
                //         Row(
                //           mainAxisAlignment: MainAxisAlignment.spaceBetween,
                //           children: [
                //             const Text('Total'),
                //             Text(
                //               ((double.parse(item.valorVenda)) * item.quantidade!).obterReal(),
                //               style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 14),
                //             ),
                //           ],
                //         ),
                //       ],
                //     ),
                //   ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
