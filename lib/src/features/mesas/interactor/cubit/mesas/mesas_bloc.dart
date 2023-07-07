import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';

import 'package:bloc/bloc.dart';

class MesasCubit extends Cubit<MesasState> {
  final MesaService _service;

  MesasCubit(this._service) : super(MesaInitialState());

  void getMesas() async {
    Map<String, dynamic> mesas = {};

    emit(MesaLoadingState());
    mesas = await _service.listar();
    emit(MesaLoadedState(mesas: mesas));
  }
}
