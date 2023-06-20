abstract class PedidosEvent {}

class GetPedidos extends PedidosEvent {
  final String idMesa;

  GetPedidos({required this.idMesa});
}
