import 'package:app/src/modulos/comandas/ui/inserir_cliente.dart';
import 'package:app/src/modulos/comandas/ui/pagina_comandas.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ComandasModule extends Module {
  @override
  void routes(r) {
    r.child(
      '/',
      child: (context) => const PaginaComandas(),
    );
    r.child(
      '/inserirCliente/',
      child: (context) => const InserirCliente(),
    );
  }
}
