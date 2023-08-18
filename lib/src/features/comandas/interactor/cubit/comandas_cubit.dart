import 'package:app/src/features/comandas/interactor/models/comandas_model.dart';
import 'package:app/src/features/comandas/interactor/services/comanda_service.dart';
import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';

import 'package:bloc/bloc.dart';

class ComandasCubit extends Cubit<ComandasState> {
  final ComandaService _service;

  ComandasCubit(this._service) : super(ComandaInitialState());

  void getComandas() async {
    ComandasModel? comandas;

    emit(ComandaLoadingState());

    try {
      comandas = await _service.listar();

      if (comandas != null) {
        emit(ComandaLoadedState(comandas: comandas));
      }
    } catch (e) {
      emit(ComandaErrorState(exception: Exception(e)));
    }
  }
}
