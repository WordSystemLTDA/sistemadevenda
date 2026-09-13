import 'falha_pedido_voz.dart';

enum DestinoPedidoVoz {
  carrinho,
  cozinha;

  static DestinoPedidoVoz interpretar(Object? valor) => switch (valor) {
        'cozinha' => cozinha,
        'carrinho' || 'nao_informado' || null => carrinho,
        _ => throw const FalhaPedidoVoz(
            'Destino do pedido indefinido. Repita se deseja carrinho ou cozinha.'),
      };
}
