import 'package:app/src/features/cardapio/interactor/models/categoria_model.dart';

sealed class ItensPedidosState {
  final List<CategoriaModel> categorias;

  ItensPedidosState({required this.categorias});
}

class CategoriaInitialState extends ItensPedidosState {
  CategoriaInitialState() : super(categorias: []);
}

class CategoriaLoadingState extends ItensPedidosState {
  CategoriaLoadingState() : super(categorias: []);
}

class CategoriaLoadedState extends ItensPedidosState {
  CategoriaLoadedState({required List<CategoriaModel> categorias}) : super(categorias: categorias);
}

class CategoriaErrorState extends ItensPedidosState {
  final Exception exception;

  CategoriaErrorState({required this.exception}) : super(categorias: []);
}
