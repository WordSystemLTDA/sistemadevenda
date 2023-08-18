import 'package:app/src/features/cardapio/interactor/models/categoria_model.dart';
import 'package:app/src/features/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/features/cardapio/interactor/states/categorias_state.dart';
import 'package:bloc/bloc.dart';

class CategoriasCubit extends Cubit<CategoriasState> {
  final CategoriaService _service;

  CategoriasCubit(this._service) : super(CategoriaInitialState());

  void getCategorias() async {
    List<CategoriaModel> categorias;

    emit(CategoriaLoadingState());
    categorias = await _service.listar();
    emit(CategoriaLoadedState(categorias: categorias));
  }
}
