import 'package:app/src/modulos/mesas/interactor/models/mesas_model.dart';

abstract interface class MesaService {
  Future<MesasModel?> listar();
}
