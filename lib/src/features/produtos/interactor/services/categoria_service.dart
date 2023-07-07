import 'package:app/src/features/produtos/interactor/models/categoria_model.dart';

abstract interface class CategoriaService {
  Future<List<CategoriaModel>> listar();
}
