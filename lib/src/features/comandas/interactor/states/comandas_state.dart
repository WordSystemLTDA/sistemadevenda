import 'package:app/src/features/comandas/interactor/models/comanda_model.dart';
import 'package:app/src/features/comandas/interactor/models/comandas_model.dart';

sealed class ComandasState {
  final ComandasModel? comandas;

  ComandasState({required this.comandas});
}

class ComandaInitialState extends ComandasState {
  ComandaInitialState() : super(comandas: ComandasModel(comandasLivres: List<ComandaModel>.empty(), comandasOcupadas: List.empty()));
}

class ComandaLoadingState extends ComandasState {
  ComandaLoadingState() : super(comandas: ComandasModel(comandasLivres: List<ComandaModel>.empty(), comandasOcupadas: List<ComandaModel>.empty()));
}

class ComandaLoadedState extends ComandasState {
  ComandaLoadedState({required ComandasModel? comandas}) : super(comandas: comandas);
}

class ComandaErrorState extends ComandasState {
  final Exception exception;

  ComandaErrorState({required this.exception}) : super(comandas: ComandasModel(comandasLivres: List<ComandaModel>.empty(), comandasOcupadas: List<ComandaModel>.empty()));
}
