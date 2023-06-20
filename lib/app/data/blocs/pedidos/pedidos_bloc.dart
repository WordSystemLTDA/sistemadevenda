

import 'package:app/app/data/blocs/pedidos/pedidos_event.dart';
import 'package:app/app/data/blocs/pedidos/pedidos_state.dart';
import 'package:app/app/data/models/pedido_model.dart';
import 'package:app/app/data/repositories/pedido_repository.dart';
import 'package:bloc/bloc.dart';

class PedidosBloc extends Bloc<PedidosEvent, PedidosState> {
  final _repository = PedidoRepository();

  PedidosBloc() : super(PedidoInitialState()) {
    on(_mapEventToState);
  }

  void _mapEventToState(PedidosEvent event, Emitter emit) async {
    List<PedidoModel> pedidos = [];

    emit(PedidoLoadingState());

    if (event is GetPedidos) {
      pedidos = await _repository.listar(event.idMesa);
    }

    emit(PedidoLoadedState(pedidos: pedidos));
  }
}
