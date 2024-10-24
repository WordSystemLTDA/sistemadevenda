// import 'package:app/src/modulos/cardapio/modelos/modelo_cortesias_produto.dart';
// import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
// import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
// import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
// import 'package:brasil_fields/brasil_fields.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_modular/flutter_modular.dart';

// class CardCortesias extends StatefulWidget {
//   final ModeloDadosOpcoesPacotes item;
//   final bool kit;
//   final ModeloProduto? dadosKit;
//   const CardCortesias({super.key, required this.item, required this.kit, this.dadosKit});

//   @override
//   State<CardCortesias> createState() => _CardCortesiasState();
// }

// class _CardCortesiasState extends State<CardCortesias> {
//   final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

//   List<Modelowordcortesiasproduto> retornarListaCortesias() {
//     if (widget.kit) {
//       var produto = _provedorProduto.listaKits.where((element) => element.id == widget.dadosKit!.id).firstOrNull;

//       if (produto == null) {
//         return [];
//       } else {
//         return produto.cortesias;
//       }
//     }

//     return _provedorProduto.listaCortesias;
//   }

//   @override
//   Widget build(BuildContext context) {
//     var item = Modelowordcortesiasproduto.fromMap(widget.item.toMap());

//     return Card(
//       child: InkWell(
//         onTap: () {
//           var sucesso = _provedorProduto.selecionarCortesia(item, widget.kit, widget.dadosKit);

//           if (sucesso == false) {
//             ScaffoldMessenger.of(context).removeCurrentSnackBar();
//             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//               content: Text('Máximo de produtos cortesia já escolhidos.'),
//               backgroundColor: Colors.red,
//               behavior: SnackBarBehavior.floating,
//             ));
//           } else {
//             if (_provedorProduto.listaCortesias.firstOrNull != null) {
//               ScaffoldMessenger.of(context).removeCurrentSnackBar();
//               ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                 content: Text("${_provedorProduto.listaCortesias.length}/${_provedorProduto.listaCortesias.first.quantimaximaselecao} Selecionados"),
//                 behavior: SnackBarBehavior.floating,
//               ));
//             }
//           }
//         },
//         borderRadius: const BorderRadius.all(Radius.circular(8)),
//         child: Padding(
//           padding: const EdgeInsets.only(top: 5, bottom: 5),
//           child: Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               Row(
//                 children: [
//                   Radio<bool>(
//                     value: true,
//                     groupValue: retornarListaCortesias().where((element) => element.id == item.id).isNotEmpty,
//                     onChanged: (bool? value) {
//                       var sucesso = _provedorProduto.selecionarCortesia(item, widget.kit, widget.dadosKit);

//                       if (sucesso == false) {
//                         ScaffoldMessenger.of(context).removeCurrentSnackBar();
//                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//                           content: Text('Máximo de produtos cortesia já escolhidos.'),
//                           backgroundColor: Colors.red,
//                         ));
//                       } else {
//                         if (_provedorProduto.listaCortesias.firstOrNull != null) {
//                           ScaffoldMessenger.of(context).removeCurrentSnackBar();
//                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                             content: Text("${_provedorProduto.listaCortesias.length}/${_provedorProduto.listaCortesias.first.quantimaximaselecao} Selecionados"),
//                             behavior: SnackBarBehavior.floating,
//                           ));
//                         }
//                       }
//                     },
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(item.nome, style: const TextStyle(fontSize: 12)),
//                       Text(
//                         double.parse(item.valor).obterReal(),
//                         style: const TextStyle(color: Colors.green, fontSize: 12),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
