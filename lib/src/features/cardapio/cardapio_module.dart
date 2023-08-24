import 'package:app/src/features/produto/ui/produto_page.dart';
import 'package:app/src/features/cardapio/ui/cardapio_page.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardapioModule extends Module {
  @override
  void routes(r) {
    r.child('/:tipo/:idLugar', child: (context) => CardapioPage(tipo: r.args.params['tipo'], idLugar: r.args.params['idLugar']));
    r.child(
      '/produto/:tipo/:idLugar',
      child: (context) => ProdutoPage(produto: r.args.data, tipo: r.args.params['tipo'], idLugar: r.args.params['idLugar']),
    );
  }
}
