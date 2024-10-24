// import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
// import 'package:app/src/modulos/produto/paginas/widgets/card_acompanhamentos.dart';
// import 'package:app/src/modulos/produto/paginas/widgets/card_adicionais.dart';
// import 'package:app/src/modulos/produto/paginas/widgets/card_itens_retiradas.dart';
// import 'package:app/src/modulos/produto/paginas/widgets/card_tamanhos.dart';
// import 'package:brasil_fields/brasil_fields.dart';
// import 'package:cached_network_image/cached_network_image.dart';
// import 'package:flutter/material.dart';

// class CardKit extends StatefulWidget {
//   final ModeloProduto item;
//   const CardKit({super.key, required this.item});

//   @override
//   State<CardKit> createState() => _CardKitState();
// }

// class _CardKitState extends State<CardKit> with TickerProviderStateMixin {
//   // final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

//   // control the state of the animation
//   late final AnimationController _controller;

//   // animation that generates value depending on tween applied
//   late final Animation<double> _animation;

//   // define the begin and the end value of an animation
//   late final Tween<double> _sizeTween;

//   // expansion state
//   bool _isExpanded = false;

//   @override
//   void initState() {
//     _controller = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 150),
//     );
//     _animation = CurvedAnimation(
//       parent: _controller,
//       curve: Curves.fastOutSlowIn,
//     );
//     _sizeTween = Tween(begin: 0, end: 1);
//     super.initState();
//   }

//   // toggle expandable without setState,
//   // so that the widget does not rebuild itself.
//   void _expandOnChanged() {
//     setState(() {
//       _isExpanded = !_isExpanded;
//     });
//     _isExpanded ? _controller.forward() : _controller.reverse();
//   }

//   // dispose the controller to release it from the memory
//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     var item = widget.item;

//     return Card(
//       child: Padding(
//         padding: const EdgeInsets.only(top: 5, bottom: 5),
//         child: Column(
//           children: [
//             SizedBox(
//               height: 70,
//               child: InkWell(
//                 onTap: () {
//                   _expandOnChanged();
//                 },
//                 child: Stack(
//                   children: [
//                     Column(
//                       children: [
//                         Expanded(
//                           child: Row(
//                             children: [
//                               ClipRRect(
//                                 borderRadius: BorderRadius.circular(5),
//                                 child: CachedNetworkImage(
//                                   width: 65,
//                                   height: 65,
//                                   fit: BoxFit.cover,
//                                   fadeOutDuration: const Duration(milliseconds: 100),
//                                   placeholder: (context, url) => const SizedBox(
//                                     child: Center(child: CircularProgressIndicator()),
//                                   ),
//                                   errorWidget: (context, url, error) => const Icon(Icons.error),
//                                   imageUrl: item.foto,
//                                 ),
//                               ),
//                               const SizedBox(width: 5),
//                               Expanded(
//                                 child: Padding(
//                                   padding: const EdgeInsets.only(left: 5, right: 20, top: 5),
//                                   child: Column(
//                                     crossAxisAlignment: CrossAxisAlignment.start,
//                                     children: [
//                                       Row(
//                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                                         children: [
//                                           Text("${item.quantidade}x ${item.nome}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
//                                           Text((double.tryParse(item.valorVenda) ?? 0).obterReal(),
//                                               style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600)),
//                                         ],
//                                       ),
//                                       const SizedBox(height: 4),
//                                       Flexible(
//                                         child: Text(
//                                           item.descricao,
//                                           style: const TextStyle(fontSize: 12),
//                                           maxLines: 2,
//                                           overflow: TextOverflow.ellipsis,
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                       ],
//                     ),
//                     if (item.opcoesPacotes!.isNotEmpty)
//                       Positioned(
//                         top: 0,
//                         right: 10,
//                         bottom: 0,
//                         child: SizedBox(
//                           width: 20,
//                           child: AnimatedSwitcher(
//                             duration: const Duration(milliseconds: 200),
//                             transitionBuilder: (child, anim) => RotationTransition(
//                               turns: child.key == const ValueKey('icon1') ? Tween<double>(begin: 0.75, end: 1).animate(anim) : Tween<double>(begin: 1, end: 1).animate(anim),
//                               child: ScaleTransition(scale: anim, child: child),
//                             ),
//                             child: _isExpanded
//                                 ? const Icon(Icons.keyboard_arrow_up_outlined, key: ValueKey('icon2'))
//                                 : const Icon(Icons.keyboard_arrow_down_outlined, key: ValueKey('icon1')),
//                           ),
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//             ),
//             SizeTransition(
//               sizeFactor: _sizeTween.animate(_animation),
//               child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//                 if (item.opcoesPacotes!.isNotEmpty) ...[
//                   const Divider(),
//                   ...item.opcoesPacotes!.map((opcoesPacote) {
//                     return Container(
//                       padding: const EdgeInsets.only(left: 5, right: 5),
//                       decoration: BoxDecoration(
//                         boxShadow: [
//                           BoxShadow(
//                             color: Colors.grey.withOpacity(0.5),
//                             blurRadius: 30.0,
//                             spreadRadius: -30,
//                           ),
//                         ],
//                       ),
//                       child: Padding(
//                         padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 7),
//                         child: ClipRRect(
//                           borderRadius: BorderRadius.circular(8),
//                           child: Card(
//                             margin: EdgeInsets.zero,
//                             color: Colors.white,
//                             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
//                             elevation: 0,
//                             child: Column(
//                               children: [
//                                 Padding(
//                                   padding: const EdgeInsets.only(left: 0, top: 10, bottom: 10),
//                                   child: Row(
//                                     crossAxisAlignment: CrossAxisAlignment.center,
//                                     children: [
//                                       Padding(
//                                         padding: const EdgeInsets.only(left: 10),
//                                         child: Text(
//                                           '${opcoesPacote.titulo} (${opcoesPacote.tipo == '1' ? opcoesPacote.dados!.length : opcoesPacote.produtos!.length})',
//                                           style: const TextStyle(fontSize: 13),
//                                         ),
//                                       ),
//                                     ],
//                                   ),
//                                 ),
//                                 ListView.builder(
//                                   shrinkWrap: true,
//                                   physics: const NeverScrollableScrollPhysics(),
//                                   itemCount: opcoesPacote.tipo == '1' ? opcoesPacote.dados!.length : opcoesPacote.produtos!.length,
//                                   padding: const EdgeInsets.only(left: 10, right: 10, bottom: 10),
//                                   itemBuilder: (context, index) {
//                                     if (opcoesPacote.id == 1) {
//                                       var itemDados = opcoesPacote.dados![index];
//                                       return CardTamanhos(item: itemDados, kit: true, dadosKit: widget.item);
//                                     } else if (opcoesPacote.id == 2) {
//                                       var itemDados = opcoesPacote.dados![index];
//                                       return CardAcompanhamentos(item: itemDados, kit: true, dadosKit: widget.item);
//                                     } else if (opcoesPacote.id == 3) {
//                                       var itemDados = opcoesPacote.dados![index];
//                                       return CardAdicionais(item: itemDados, kit: true, dadosKit: widget.item);
//                                     } else if (opcoesPacote.id == 4) {
//                                       var itemDados = opcoesPacote.dados![index];
//                                       return CardItensRetiradas(item: itemDados, kit: true, dadosKit: widget.item);
//                                     } else if (opcoesPacote.id == 5) {
//                                       var itemDados = opcoesPacote.produtos![index];
//                                       return CardKit(item: itemDados);
//                                     }
//                                     return null;
//                                   },
//                                 ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                     );
//                   }),
//                 ],
//               ]),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
