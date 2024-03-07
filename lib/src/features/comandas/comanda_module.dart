import 'package:app/src/features/comandas/ui/comandas_page.dart';
import 'package:app/src/features/comandas/ui/inserir_cliente.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ComandasModule extends Module {
  @override
  void routes(r) {
    r.child(
      '/',
      child: (context) => const ComandasPage(),
    );
    r.child(
      '/inserirCliente/',
      child: (context) => const InserirCliente(),
    );
    // r.child(
    //   '/produto/:tipo/:idComanda/:idMesa',
    //   child: (context) => ProdutoPage(
    //     produto: r.args.data,
    //     tipo: r.args.params['tipo'],
    //     idComanda: r.args.params['idComanda'],
    //     idMesa: r.args.params['idMesa'],
    //   ),
    // );
  }
}
