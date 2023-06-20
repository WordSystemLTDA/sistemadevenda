
import 'package:app/app/data/blocs/mesas/mesas_event.dart';
import 'package:app/app/data/blocs/mesas/mesas_state.dart';
import 'package:app/app/data/repositories/mesa_repository.dart';

import 'package:bloc/bloc.dart';

class MesasBloc extends Bloc<MesasEvent, MesasState> {
  final _repository = MesaRepository();

  MesasBloc() : super(MesaInitialState()) {
    on(_mapEventToState);
  }

  void _mapEventToState(MesasEvent event, Emitter emit) async {
    Map<String, dynamic> mesas = {};

    emit(MesaLoadingState());

    if (event is GetMesas) {
      mesas = await _repository.listar();
    }

    emit(MesaLoadedState(mesas: mesas));
  }
}
