
import 'package:app/app/data/blocs/produtos/produtos_event.dart';
import 'package:app/app/data/blocs/produtos/produtos_state.dart';
import 'package:app/app/data/models/produto_model.dart';
import 'package:app/app/data/repositories/produto_repository.dart';

import 'package:bloc/bloc.dart';

class ProdutosBloc extends Bloc<ProdutosEvent, ProdutosState> {
  final _repository = ProdutoRepository();

  ProdutosBloc() : super(ProdutoInitialState()) {
    on(_mapEventToState);
  }

  void _mapEventToState(ProdutosEvent event, Emitter emit) async {
    List<ProdutoModel> produtos = [];

    emit(ProdutoLoadingState());

    if (event is GetProdutos) {
      produtos = await _repository.listar(event.category);
    }

    emit(ProdutoLoadedState(produtos: produtos));
  }
}
