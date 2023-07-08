import 'package:app/src/features/mesas/interactor/models/mesa_model.dart';
import 'package:app/src/features/mesas/interactor/models/mesas_model.dart';

sealed class MesasState {
  final MesasModel? mesas;

  MesasState({required this.mesas});
}

class MesaInitialState extends MesasState {
  MesaInitialState() : super(mesas: MesasModel(mesasLivres: List<MesaModel>.empty(), mesasOcupadas: List.empty()));
}

class MesaLoadingState extends MesasState {
  MesaLoadingState() : super(mesas: MesasModel(mesasLivres: List<MesaModel>.empty(), mesasOcupadas: List<MesaModel>.empty()));
}

class MesaLoadedState extends MesasState {
  MesaLoadedState({required MesasModel? mesas}) : super(mesas: mesas);
}

class MesaErrorState extends MesasState {
  final Exception exception;

  MesaErrorState({required this.exception}) : super(mesas: MesasModel(mesasLivres: List<MesaModel>.empty(), mesasOcupadas: List<MesaModel>.empty()));
}
