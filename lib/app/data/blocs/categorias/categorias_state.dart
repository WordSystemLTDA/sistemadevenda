import 'package:app/app/data/models/categoria_model.dart';

abstract class CategoriasState {
  final List<CategoriaModel> categorias;

  CategoriasState({required this.categorias});
}

class CategoriaInitialState extends CategoriasState {
  CategoriaInitialState() : super(categorias: []);
}

class CategoriaLoadingState extends CategoriasState {
  CategoriaLoadingState() : super(categorias: []);
}

class CategoriaLoadedState extends CategoriasState {
  CategoriaLoadedState({required List<CategoriaModel> categorias}) : super(categorias: categorias);
}

class CategoriaErrorState extends CategoriasState {
  final Exception exception;

  CategoriaErrorState({required this.exception}) : super(categorias: []);
}
