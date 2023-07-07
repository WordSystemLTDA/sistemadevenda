import 'package:app/src/features/pedidos/interactor/models/pedido_model.dart';
import 'package:app/src/features/pedidos/interactor/services/pedidos_service.dart';
import 'package:app/src/features/pedidos/interactor/states/pedidos_state.dart';
import 'package:bloc/bloc.dart';

class PedidosCubit extends Cubit<PedidosState> {
  final PedidoService _service;

  PedidosCubit(this._service) : super(PedidoInitialState());

  void getPedidos(idMesa) async {
    List<PedidoModel> pedidos = [];

    emit(PedidoLoadingState());
    pedidos = await _service.listar(idMesa);
    emit(PedidoLoadedState(pedidos: pedidos));
  }
}
