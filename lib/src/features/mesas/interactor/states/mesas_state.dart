sealed class MesasState {
  final Map<String, dynamic> mesas;

  MesasState({required this.mesas});
}

class MesaInitialState extends MesasState {
  MesaInitialState() : super(mesas: {});
}

class MesaLoadingState extends MesasState {
  MesaLoadingState() : super(mesas: {});
}

class MesaLoadedState extends MesasState {
  MesaLoadedState({required Map<String, dynamic> mesas}) : super(mesas: mesas);
}

class MesaErrorState extends MesasState {
  final Exception exception;

  MesaErrorState({required this.exception}) : super(mesas: {});
}
