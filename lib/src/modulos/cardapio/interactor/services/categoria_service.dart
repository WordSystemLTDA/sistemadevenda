import 'package:app/src/modulos/cardapio/interactor/models/categoria_model.dart';

abstract interface class CategoriaService {
  Future<List<CategoriaModel>> listar();
}
