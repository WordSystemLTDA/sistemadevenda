import 'pedido_falado.dart';

enum AcaoPedidoVoz { adicionar, buscar }

AcaoPedidoVoz identificarAcaoPedidoVoz(String fala) {
  final texto = normalizarNomeVoz(fala);
  final busca = RegExp(
    r'\b(busca|buscar|busque|busquem|pesquisa|pesquisar|pesquise|procura|procurar|procure|lista|listar|liste|mostra|mostrar|mostre|encontra|encontrar|encontre|localiza|localizar|localize)\b',
  ).firstMatch(texto);
  if (busca != null) {
    return AcaoPedidoVoz.buscar;
  }
  return AcaoPedidoVoz.adicionar;
}

String termoBuscaPedidoVoz(List<PedidoFalado> pedidos) {
  if (pedidos.length != 1) {
    throw const FalhaPedidoVoz(
        'Fale apenas um produto por vez para pesquisar.');
  }
  final pedido = pedidos.single;
  final nome = pedido.pizza
      ? (pedido.sabores.isEmpty ? pedido.produto : pedido.sabores.first)
      : pedido.produto;
  if (nome.trim().isEmpty) {
    throw const FalhaPedidoVoz(
        'Nao consegui identificar o produto da pesquisa.');
  }
  return nome.trim();
}
