import 'package:app/src/features/comandas/data/services/comanda_service_impl.dart';
import 'package:flutter/material.dart';

final ValueNotifier comandasState = ValueNotifier([]);

class ComandasState {
  final ComandaServiceImpl _service = ComandaServiceImpl();

  Future<void> listarComandas() async {
    final res = await _service.listar();
    comandasState.value = res;
  }
}

// import 'package:app/src/features/comandas/interactor/models/comanda_model.dart';
// import 'package:app/src/features/comandas/interactor/models/comandas_model.dart';

// sealed class ComandasState {
//   final List<ComandasModel> comandas;

//   ComandasState({required this.comandas});
// }

// class ComandaInitialState extends ComandasState {
//   // ComandaInitialState() : super(comandas: ComandasModel(comandasLivres: List<ComandaModel>.empty(), comandasOcupadas: List.empty()));
//   ComandaInitialState() : super(comandas: []);
// }

// class ComandaLoadingState extends ComandasState {
//   ComandaLoadingState() : super(comandas: []);
//   // ComandaLoadingState() : super(comandas: ComandasModel(comandasLivres: List<ComandaModel>.empty(), comandasOcupadas: List<ComandaModel>.empty()));
// }

// class ComandaLoadedState extends ComandasState {
//   ComandaLoadedState({required List<ComandasModel> comandas}) : super(comandas: comandas);
// }

// class ComandaErrorState extends ComandasState {
//   final Exception exception;

//   ComandaErrorState({required this.exception})
//       // : super(comandas: ComandasModel(comandasLivres: List<ComandaModel>.empty(), comandasOcupadas: List<ComandaModel>.empty()));
//       : super(comandas: []);
// }