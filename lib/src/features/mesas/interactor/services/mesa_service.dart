import 'package:app/src/features/mesas/interactor/models/mesas_model.dart';

abstract interface class MesaService {
  Future<MesasModel?> listar();
}
