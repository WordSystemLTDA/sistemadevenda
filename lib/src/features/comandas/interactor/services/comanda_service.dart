import 'package:app/src/features/comandas/interactor/models/comandas_model.dart';

abstract interface class ComandaService {
  Future<List<ComandasModel>> listar();
}
