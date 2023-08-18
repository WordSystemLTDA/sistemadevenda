import 'package:app/src/features/produto/ui/produto_page.dart';
import 'package:app/src/features/cardapio/ui/cardapio_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioModule extends Module {
  @override
  void routes(r) {
    r.child('/', child: (context) => const CardapioPage());
    r.child('/mesa/:id', child: (context) => CardapioPage(id: r.args.params['id']));
    r.child('/comanda/:id', child: (context) => CardapioPage(id: r.args.params['id']));
    r.child('/produto', child: (context) => ProdutoPage(produto: r.args.data));
  }
}
