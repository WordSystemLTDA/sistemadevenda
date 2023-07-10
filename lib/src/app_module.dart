import 'package:app/src/features/home/ui/home_page.dart';
import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/features/mesas/interactor/cubit/mesas_cubit.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/mesas/ui/mesas_page.dart';
import 'package:app/src/features/produto/ui/produto_page.dart';
import 'package:app/src/features/produtos/data/services/categoria_service_impl.dart';
import 'package:app/src/features/produtos/data/services/produto_service_impl.dart';
import 'package:app/src/features/produtos/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/produtos/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/produtos/interactor/services/categoria_service.dart';
import 'package:app/src/features/produtos/interactor/services/produto_service.dart';
import 'package:app/src/features/produtos/ui/produtos_page.dart';
import 'package:dio/dio.dart';
import 'package:flutter_modular/flutter_modular.dart';

class AppModule extends Module {
  @override
  List<Bind> get binds => [
        Bind.instance<Dio>(Dio()),
        AutoBind.factory<CategoriaService>(CategoriaServiceImpl.new),
        AutoBind.factory<ProdutoService>(ProdutoServiceImpl.new),
        AutoBind.factory<MesaService>(MesaServiceImpl.new),
        AutoBind.factory<ProdutosCubit>(ProdutosCubit.new),
        AutoBind.singleton<CategoriasCubit>(CategoriasCubit.new),
        AutoBind.singleton<MesasCubit>(MesasCubit.new),
      ];

  @override
  List<ModularRoute> get routes => [
        ChildRoute('/', child: (context, args) => const HomePage()),
        ChildRoute('/mesas', child: (context, args) => const MesasPage()),
        ChildRoute('/produtos/:idMesa', child: (context, args) => ProdutosPage(idMesa: args.params['idMesa'])),
        ChildRoute('/produto', child: (context, args) => ProdutoPage(produto: args.data)),
      ];
}
