
import 'package:app/app/data/models/pedido_model.dart';

abstract class PedidosState {
  final List<PedidoModel> pedidos;

  PedidosState({required this.pedidos});
}

class PedidoInitialState extends PedidosState {
  PedidoInitialState() : super(pedidos: []);
}

class PedidoLoadingState extends PedidosState {
  PedidoLoadingState() : super(pedidos: []);
}

class PedidoLoadedState extends PedidosState {
  PedidoLoadedState({required List<PedidoModel> pedidos}) : super(pedidos: pedidos);
}

class PedidoErrorState extends PedidosState {
  final Exception exception;

  PedidoErrorState({required this.exception}) : super(pedidos: []);
}
