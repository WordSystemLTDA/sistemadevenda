import '../cardapio/modelos/modelo_produto.dart';
import 'pedido_falado.dart';

class LotePedidoVoz {
  final String texto;
  final List<PedidoFalado> pedidos;
  final List<Modelowordprodutos> itens;
  const LotePedidoVoz(
      {required this.texto, required this.pedidos, required this.itens});

  static List<PedidoFalado> lerPedidos(Map dados) {
    final esclarecimento = dados['esclarecimento'];
    if (esclarecimento is! String || esclarecimento.length > 500) {
      throw const FalhaPedidoVoz('Resposta incompleta. Repita o pedido.');
    }
    if (esclarecimento.trim().isNotEmpty) {
      throw FalhaPedidoVoz(esclarecimento.trim());
    }
    final itens = dados['itens'];
    if (itens is! List || itens.length > 20) {
      throw const FalhaPedidoVoz('Informe até 20 itens por pedido.');
    }
    return itens.map((item) {
      if (item is! Map) {
        throw const FalhaPedidoVoz('Um dos itens veio incompleto.');
      }
      return PedidoFalado.fromMap(
          {...item, 'esclarecimento': '', 'destino': 'carrinho'},
          lote: true);
    }).toList();
  }

  Map<String, dynamic> get rascunho => {
        'itens': pedidos.map((e) => e.toMap()).toList(),
        'esclarecimento': '',
      };

  LotePedidoVoz remover(int indice) => LotePedidoVoz(
      texto: texto,
      pedidos: [...pedidos]..removeAt(indice),
      itens: [...itens]..removeAt(indice));
}
