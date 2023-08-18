import 'package:app/src/features/comandas/data/services/comanda_service_impl.dart';
import 'package:app/src/features/comandas/interactor/cubit/comandas_cubit.dart';
import 'package:app/src/features/comandas/interactor/services/comanda_service.dart';
import 'package:app/src/features/comandas/ui/comandas_page.dart';
import 'package:app/src/features/home/ui/home_page.dart';
import 'package:app/src/features/login/data/services/autenticacao_service_impl.dart';
import 'package:app/src/features/login/interactor/cubit/autenticacao_cubit.dart';
import 'package:app/src/features/login/interactor/services/autenticacao_service.dart';
import 'package:app/src/features/login/ui/login_page.dart';
import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/features/mesas/interactor/cubit/mesas_cubit.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/mesas/ui/mesas_page.dart';
import 'package:app/src/features/produto/interactor/cubit/counter_cubit.dart';
import 'package:app/src/features/cardapio/data/services/categoria_service_impl.dart';
import 'package:app/src/features/cardapio/data/services/produto_service_impl.dart';
import 'package:app/src/features/cardapio/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/cardapio/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/cardapio/interactor/services/categoria_service.dart';
import 'package:app/src/features/cardapio/interactor/services/produto_service.dart';
import 'package:app/src/features/cardapio/cardapio_module.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  void binds(i) {
    i.addInstance(Dio());
    i.add<CategoriaService>(CategoriaServiceImpl.new);
    i.add<ProdutoService>(ProdutoServiceImpl.new);
    i.add<MesaService>(MesaServiceImpl.new);
    i.add<ComandaService>(ComandaServiceImpl.new);
    i.add<AutenticacaoService>(AutenticacaoServiceImpl.new);
    i.add<ProdutosCubit>(ProdutosCubit.new);
    i.add<CounterCubit>(CounterCubit.new);
    i.add<AutenticacaoCubit>(AutenticacaoCubit.new);
    i.addSingleton<CategoriasCubit>(CategoriasCubit.new);
    i.addSingleton<MesasCubit>(MesasCubit.new);
    i.addSingleton<ComandasCubit>(ComandasCubit.new);
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
