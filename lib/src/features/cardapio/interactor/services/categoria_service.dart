import 'package:app/src/features/cardapio/interactor/models/categoria_model.dart';

abstract interface class CategoriaService {
  Future<List<CategoriaModel>> listar();
}
