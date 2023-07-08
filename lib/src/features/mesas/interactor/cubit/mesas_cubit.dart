import 'package:app/src/features/mesas/interactor/models/mesas_model.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';

import 'package:bloc/bloc.dart';

class MesasCubit extends Cubit<MesasState> {
  final MesaService _service;

  MesasCubit(this._service) : super(MesaInitialState());

  void getMesas() async {
    MesasModel? mesas;

    emit(MesaLoadingState());

    try {
      mesas = await _service.listar();

      if (mesas != null) {
        emit(MesaLoadedState(mesas: mesas));
      }
    } catch (e) {
      emit(MesaErrorState(exception: Exception(e)));
    }
  }
}
