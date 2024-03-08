import 'package:app/src/modulos/mesas/ui/pagina_abrir_mesa.dart';
import 'package:app/src/modulos/mesas/ui/pagina_lista_mesas.dart';
import 'package:app/src/modulos/mesas/ui/pagina_mesas.dart';
import 'package:flutter_modular/flutter_modular.dart';

class MesasModule extends Module {
  @override
  void routes(r) {
    r.child(
      '/',
      child: (context) => const PaginaMesas(),
    );
    r.child(
      '/todasMesas/',
      child: (context) => const PaginaListaMesas(),
    );
    r.child(
      '/abrirMesa/:id/:nome/',
      child: (context) => PaginaAbrirMesa(
        id: r.args.params['id'],
        nome: r.args.params['nome'].toString(),
      ),
    );
  }
}
