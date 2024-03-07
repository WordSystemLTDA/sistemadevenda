import 'package:app/src/features/cardapio/cardapio_module.dart';
import 'package:app/src/features/cardapio/data/services/categoria_service_impl.dart';
import 'package:app/src/features/cardapio/data/services/produto_service_impl.dart';
import 'package:app/src/features/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/features/cardapio/interactor/services/produto_service.dart';
import 'package:app/src/features/comandas/comanda_module.dart';
import 'package:app/src/features/home/ui/home_page.dart';
import 'package:app/src/features/login/data/services/autenticacao_service_impl.dart';
import 'package:app/src/features/login/interactor/services/autenticacao_service.dart';
import 'package:app/src/features/login/ui/login_page.dart';
import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/mesas/ui/mesas_page.dart';
import 'package:app/src/features/mesas/ui/todas_mesas.dart';
import 'package:app/src/features/produto/interactor/provedor/produto_provedor.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(Dio());

    // Categorias
    i.add<CategoriaService>(CategoriaServiceImpl.new);

    // Mesas
    i.add<MesaService>(MesaServiceImpl.new);

    // Comandas
    i.add<ProdutoProvedor>(ProdutoProvedor.new);

    // Autenticacao
    i.add<AutenticacaoService>(AutenticacaoServiceImpl.new);

    // Produto
    i.add<ProdutoService>(ProdutoServiceImpl.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (context) => const LoginPage());
    r.child('/inicio', child: (context) => const HomePage(), transition: TransitionType.defaultTransition);
    r.child('/mesas', child: (context) => const MesasPage(), transition: TransitionType.defaultTransition);
    r.child('/todasMesas', child: (context) => const TodasMesas(), transition: TransitionType.defaultTransition);
    r.module('/comandas', module: ComandasModule(), transition: TransitionType.defaultTransition);
    r.module('/cardapio', module: CardapioModule(), transition: TransitionType.defaultTransition);
  }
}
