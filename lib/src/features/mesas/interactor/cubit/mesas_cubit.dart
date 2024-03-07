

// import 'package:bloc/bloc.dart';

// class MesasCubit extends Cubit<MesasState> {
//   final MesaService _service;

//   MesasCubit(this._service) : super(MesaInitialState());

//   void getMesas() async {
//     MesasModel? mesas;

//     emit(MesaLoadingState());

//     try {
//       mesas = await _service.listar();

//       if (mesas != null) {
//         emit(MesaLoadedState(mesas: mesas));
//       }
//     } catch (e) {
//       emit(MesaErrorState(exception: Exception(e)));
//     }
//   }
// }
