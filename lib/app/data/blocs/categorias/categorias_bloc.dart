
import 'package:app/app/data/blocs/categorias/categorias_event.dart';
import 'package:app/app/data/blocs/categorias/categorias_state.dart';
import 'package:app/app/data/models/categoria_model.dart';
import 'package:app/app/data/repositories/categoria_repository.dart';
import 'package:bloc/bloc.dart';

class CategoriasBloc extends Bloc<CategoriasEvent, CategoriasState> {
  final _repository = CategoriaRepository();

  CategoriasBloc() : super(CategoriaInitialState()) {
    on(_mapEventToState);
  }

  void _mapEventToState(CategoriasEvent event, Emitter emit) async {
    List<CategoriaModel> categorias = [];

    emit(CategoriaLoadingState());

    if (event is GetCategorias) {
      categorias = await _repository.listar();
    }

    emit(CategoriaLoadedState(categorias: categorias));
  }
}
