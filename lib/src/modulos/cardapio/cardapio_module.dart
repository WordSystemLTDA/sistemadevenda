import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioModule extends Module {
  @override
  void routes(r) {
    r.child(
      '/:tipo/:idComanda/:idMesa',
      child: (context) => PaginaCardapio(
        tipo: r.args.params['tipo'],
        idComanda: r.args.params['idComanda'],
        idMesa: r.args.params['idMesa'],
      ),
    );
    r.child(
      '/produto/:tipo/:idComanda/:idMesa',
      child: (context) => PaginaProduto(
        produto: r.args.data,
        tipo: r.args.params['tipo'],
        idComanda: r.args.params['idComanda'],
        idMesa: r.args.params['idMesa'],
      ),
    );
    r.child(
      '/carrinho/:idComanda/:idMesa',
      child: (context) => PaginaCarrinho(
        idComanda: r.args.params['idComanda'],
        idMesa: r.args.params['idMesa'],
      ),
    );
  }
}
