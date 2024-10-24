// import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
// import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
// import 'package:app/src/modulos/cardapio/modelos/modelo_tamanhos_produto.dart';
// import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
// import 'package:brasil_fields/brasil_fields.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_modular/flutter_modular.dart';

// class CardTamanhos extends StatefulWidget {
//   final ModeloDadosOpcoesPacotes item;
//   final bool kit;
//   final ModeloProduto? dadosKit;
//   const CardTamanhos({super.key, required this.item, required this.kit, this.dadosKit});

//   @override
//   State<CardTamanhos> createState() => _CardTamanhosState();
// }

// class _CardTamanhosState extends State<CardTamanhos> {
//   final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();

//   List<Modelowordtamanhosproduto> retornarListaTamanhos() {
//     if (widget.kit) {
//       var produto = _provedorProduto.listaKits.where((element) => element.id == widget.dadosKit!.id).firstOrNull;

//       if (produto == null) {
//         return [];
//       } else {
//         return produto.tamanhos;
//       }
//     }

//     return _provedorProduto.listaTamanhos;
//   }

//   @override
//   Widget build(BuildContext context) {
//     var item = Modelowordtamanhosproduto.fromMap(widget.item.toMap());

//     return Card(
//       child: InkWell(
//         onTap: () {
//           _provedorProduto.mudarTamanhoSelecionado(item, widget.kit, widget.dadosKit);
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
//                     groupValue: retornarListaTamanhos().where((element) => element.id == item.id).isNotEmpty,
//                     onChanged: (bool? value) {
//                       _provedorProduto.mudarTamanhoSelecionado(item, widget.kit, widget.dadosKit);
//                     },
//                   ),
//                   Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       Text(item.nome),
//                       Text(
//                         double.parse(item.valor).obterReal(),
//                         style: const TextStyle(color: Colors.green),
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
