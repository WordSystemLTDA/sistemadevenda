import 'package:app/src/features/cardapio/interactor/models/produto_model.dart';
import 'package:app/src/features/cardapio/interactor/services/produto_service.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';

import 'package:bloc/bloc.dart';

class ProdutosCubit extends Cubit<ProdutosState> {
  final ProdutoService _service;

  ProdutosCubit(this._service) : super(ProdutoInitialState());

  void getProdutos(category) async {
    List<ProdutoModel>? produtos = [];

    emit(ProdutoLoadingState());
    produtos = await _service.listar(category);
    print(produtos);
    emit(ProdutoLoadedState(produtos: produtos));
  }
}
