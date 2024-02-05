import 'package:app/src/features/cardapio/data/services/produto_service_impl.dart';
import 'package:app/src/features/cardapio/interactor/models/lista_produtos_modelo.dart';
import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:flutter/material.dart';

// class ProdutoState extends ChangeNotifier {
//   final ProdutoServiceImpl _service = ProdutoServiceImpl();

//   List<ListaProdutosModelo> listaProdutoState = [];

//   void listarProdutos(String category) async {
//     final res = await _service.listar(category);
//     if (res.isEmpty) return;

//     final contain = listaProdutoState.where((e) => e.categoria == category);

//     if (contain.isNotEmpty) {
//       final int index = listaProdutoState.indexWhere((e) => e.categoria == category);
//       listaProdutoState[index] = ListaProdutosModelo(categoria: category, listaProdutos: res);
//     } else {
//       listaProdutoState = [...listaProdutoState, ListaProdutosModelo(categoria: category, listaProdutos: res)];
//     }
//     notifyListeners();
//   }
// }

class ProdutoState extends ValueNotifier {
  ProdutoState(super.value);

  final ProdutoServiceImpl _service = ProdutoServiceImpl();

  Future<void> listarProdutosPorCategoria(String category) async {
    final res = await _service.listarPorCategoria(category);
    if (res.isEmpty) return;

    final contain = value.where((e) => e.categoria == category);

    if (contain.isNotEmpty) {
      final int index = value.indexWhere((e) => e.categoria == category);
      value[index] = ListaProdutosModelo(categoria: category, listaProdutos: res);
    } else {
      value = [...value, ListaProdutosModelo(categoria: category, listaProdutos: res)];
    }
  }

  Future<List<ProdutoModel>> listarProdutosPorNome(String pesquisa) async {
    return await _service.listarPorNome(pesquisa);
  }
}

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \\
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \\
// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - \\

// final ValueNotifier<List<ListaProdutosModelo>> produtoState = ValueNotifier([]);

// class ProdutoState {
//   final ProdutoServiceImpl _service = ProdutoServiceImpl();

//   void listarProdutos(String category) async {
//     final res = await _service.listar(category);
//     if (res.isEmpty) return;

//     final contain = produtoState.value.where((e) => e.categoria == category);

//     if (contain.isNotEmpty) {
//       final int index = produtoState.value.indexWhere((e) => e.categoria == category);
//       produtoState.value[index] = ListaProdutosModelo(categoria: category, listaProdutos: res);
//     } else {
//       // produtoState.value.add(
//       //   ListaProdutosModelo(categoria: category, listaProdutos: res),
//       // );
//       produtoState.value = [...produtoState.value, ListaProdutosModelo(categoria: category, listaProdutos: res)];

//       // print('foi');
//       // print(produtoState.value[0].categoria);
//     }
//   }
// }
