import 'package:app/src/features/produto/interactor/services/salvar_produto_service.dart';
import 'package:app/src/features/produto/interactor/states/salvar_produto_state.dart';

import 'package:bloc/bloc.dart';

class SalvarProdutoCubit extends Cubit<SalvarProdutoState> {
  final SalvarProdutoService _service;

  SalvarProdutoCubit(this._service) : super(SalvarProdutoInicioState());

  void inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao) async {
    bool sucesso = false;

    emit(SalvarProdutoCarregandoState());

    sucesso = await _service.inserir(idComanda, valor, observacaoMesa, idProduto, quantidade, observacao);

    if (sucesso) {
      emit(SalvarProdutoSucessoState());
    } else {
      emit(SalvarProdutoErroState(exception: Exception('Erro ao tentar inserir')));
    }
  }
}
