import 'package:app/src/features/comandas/data/services/comanda_service_impl.dart';
import 'package:app/src/features/comandas/interactor/services/comanda_service.dart';
import 'package:app/src/features/comandas/ui/comandas_page.dart';
import 'package:app/src/features/home/ui/home_page.dart';
import 'package:app/src/features/login/data/services/autenticacao_service_impl.dart';
import 'package:app/src/features/login/interactor/services/autenticacao_service.dart';
import 'package:app/src/features/login/ui/login_page.dart';
import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/mesas/ui/mesas_page.dart';
import 'package:app/src/features/produto/data/services/salvar_produto_service_impl.dart';
import 'package:app/src/features/cardapio/data/services/categoria_service_impl.dart';
import 'package:app/src/features/cardapio/data/services/produto_service_impl.dart';
import 'package:app/src/features/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/features/cardapio/interactor/services/produto_service.dart';
import 'package:app/src/features/cardapio/cardapio_module.dart';
import 'package:app/src/features/produto/interactor/services/salvar_produto_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(Dio());

    // Categorias
    i.add<CategoriaService>(CategoriaServiceImpl.new);
    // i.addSingleton<CategoriasCubit>(CategoriasCubit.new);

    // Mesas
    i.add<MesaService>(MesaServiceImpl.new);
    // i.addSingleton<MesasCubit>(MesasCubit.new);

    // Comandas
    // i.addSingleton<ComandasCubit>(ComandasCubit.new);
    i.add<ComandaService>(ComandaServiceImpl.new);

    // Autenticacao
    // i.add<AutenticacaoCubit>(AutenticacaoCubit.new);
    i.add<AutenticacaoService>(AutenticacaoServiceImpl.new);

    // Produto
    i.add<ProdutoService>(ProdutoServiceImpl.new);
    i.add<SalvarProdutoService>(SalvarProdutoServiceImpl.new);
    // i.add<CounterCubit>(CounterCubit.new);
    // i.add<SalvarProdutoCubit>(SalvarProdutoCubit.new);
  }

  @override
  void routes(r) {
    r.child('/', child: (context) => const LoginPage());
    r.child('/inicio', child: (context) => const HomePage(), transition: TransitionType.rightToLeft);
    r.child('/mesas', child: (context) => const MesasPage(), transition: TransitionType.rightToLeft);
    r.child('/comandas', child: (context) => const ComandasPage(), transition: TransitionType.rightToLeft);
    r.module('/cardapio', module: CardapioModule(), transition: TransitionType.rightToLeft);
  }
}
