import 'package:app/src/features/pedidos/interactor/models/pedido_model.dart';

abstract interface class PedidoService {
  Future<List<PedidoModel>> listar(String idMesa);
}
