// import 'dart:convert';

// import 'package:e_commerce/src/modulos/carrinho/modelos/carrinho_modelo.dart';
// import 'package:flutter/material.dart';
// import 'package:shared_preferences/shared_preferences.dart';

// final ValueNotifier<List<CarrinhoModelo>> listaCarrinho = ValueNotifier([]);
// final ValueNotifier<int> quantDoCarrinho = ValueNotifier(0);
// final ValueNotifier<List<String>> idsQueEstaNoCarrinho = ValueNotifier([]);

// class ProvedoresCarrinho {
//   Future<void> listar() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     final List dados = jsonDecode(prefs.getString('carrinho') ?? '[]');

//     listaCarrinho.value = List<CarrinhoModelo>.from(dados.map((elemento) {
//       return CarrinhoModelo.fromMap(elemento);
//     }));
//   }

//   Future<List<Map<String, dynamic>>> listarIds() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     final List dados = jsonDecode(prefs.getString('carrinho') ?? '[]');

//     final elementos = List<CarrinhoModelo>.from(dados.map((elemento) {
//       return CarrinhoModelo.fromMap(elemento);
//     }));

//     return [
//       ...elementos.map((e) => {'id': e.id, 'quantidade': e.quantidade, 'habil_tipo': e.habilTipo, 'idTamanho': e.idTamanho}),
//     ];
//   }

//   Future<bool> inserir(CarrinhoModelo modelo, {required bool podeRemover}) async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     final List<CarrinhoModelo> dados = List<CarrinhoModelo>.from(jsonDecode(prefs.getString('carrinho') ?? '[]').map((elemento) {
//       return CarrinhoModelo.fromMap(elemento);
//     }));

//     if (podeRemover) {
//       for (int index = 0; index < dados.length; index++) {
//         final item = dados[index];

//         if (item.id == modelo.id) {
//           final res = await prefs.setString(
//             'carrinho',
//             jsonEncode(
//               [
//                 ...dados.where((e) => e.id != item.id).map((e) => e.toMap()),
//               ],
//             ),
//           );

//           buscarQuantDoCarrinho();
//           listarIdsQueEstaNoCarrinho();

//           return res;
//         }
//       }
//     }

//     final res = await prefs.setString(
//       'carrinho',
//       jsonEncode(
//         [
//           ...dados.map((e) => e.toMap()),
//           {...modelo.toMap()}
//         ],
//       ),
//     );

//     buscarQuantDoCarrinho();
//     listarIdsQueEstaNoCarrinho();

//     return res;
//   }

//   Future<bool> alterarQuantidade(String id, bool incrementar, int quantidade) async {
//     if (!incrementar && quantidade <= 1) return false;

//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     final List<CarrinhoModelo> dados = List<CarrinhoModelo>.from(jsonDecode(prefs.getString('carrinho') ?? '[]').map((elemento) {
//       return CarrinhoModelo.fromMap(elemento);
//     }));

//     return await prefs.setString(
//       'carrinho',
//       jsonEncode(
//         [
//           ...dados.map((e) {
//             if (e.id == id) {
//               return CarrinhoModelo(
//                 id: e.id,
//                 imagem: e.imagem,
//                 rotulo: e.rotulo,
//                 marca: e.marca,
//                 preco: e.preco,
//                 habilTipo: e.habilTipo,
//                 idTamanho: e.idTamanho,
//                 nomeTamanho: e.nomeTamanho,
//                 quantidade: incrementar ? ++quantidade : --quantidade,
//               ).toMap();
//             }
//             return e.toMap();
//           }),
//         ],
//       ),
//     );
//   }

//   Future<bool> remover(String id) async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     final List<CarrinhoModelo> dados = List<CarrinhoModelo>.from(jsonDecode(prefs.getString('carrinho') ?? '[]').map((elemento) {
//       return CarrinhoModelo.fromMap(elemento);
//     }));

//     final res = await prefs.setString(
//       'carrinho',
//       jsonEncode(
//         [
//           ...dados.where((e) => e.id != id).map((e) => e.toMap()),
//         ],
//       ),
//     );

//     buscarQuantDoCarrinho();
//     listarIdsQueEstaNoCarrinho();

//     return res;
//   }

//   Future<bool> removerTodos() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();
//     final res = prefs.remove("carrinho");

//     buscarQuantDoCarrinho();
//     listarIdsQueEstaNoCarrinho();

//     return res;
//   }

//   void buscarQuantDoCarrinho() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     quantDoCarrinho.value = jsonDecode(prefs.getString('carrinho') ?? '[]').length;
//   }

//   void listarIdsQueEstaNoCarrinho() async {
//     final SharedPreferences prefs = await SharedPreferences.getInstance();

//     final List dados = jsonDecode(prefs.getString('carrinho') ?? '[]');

//     idsQueEstaNoCarrinho.value = [...dados.map((e) => e['id'])];
//   }
// }
