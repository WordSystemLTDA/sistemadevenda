import 'package:app/src/app_widget.dart';
import 'package:app/src/features/mesas/data/services/mesa_service_impl.dart';
import 'package:app/src/features/mesas/interactor/cubit/mesas_cubit.dart';
import 'package:app/src/features/mesas/interactor/services/mesa_service.dart';
import 'package:app/src/features/pedidos/data/services/pedido_service_impl.dart';
import 'package:app/src/features/pedidos/interactor/cubit/pedidos_cubit.dart';
import 'package:app/src/features/pedidos/interactor/services/pedidos_service.dart';
import 'package:app/src/features/produtos/data/services/categoria_service_impl.dart';
import 'package:app/src/features/produtos/data/services/produto_service_impl.dart';
import 'package:app/src/features/produtos/interactor/cubit/categorias_cubit.dart';
import 'package:app/src/features/produtos/interactor/cubit/produtos_cubit.dart';
import 'package:app/src/features/produtos/interactor/services/categoria_service.dart';
import 'package:app/src/features/produtos/interactor/services/produto_service.dart';
import 'package:dio/dio.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';

void main() {
  final app = MultiProvider(
    providers: [
      Provider.value(value: Dio()),
      Provider<CategoriaService>(create: (context) => CategoriaServiceImpl(context.read())),
      Provider<ProdutoService>(create: (context) => ProdutoServiceImpl(context.read())),
      Provider<PedidoService>(create: (context) => PedidoServiceImpl(context.read())),
      Provider<MesaService>(create: (context) => MesaServiceImpl(context.read())),
      BlocProvider(create: (context) => CategoriasCubit(context.read())),
      BlocProvider(create: (context) => ProdutosCubit(context.read())),
      BlocProvider(create: (context) => PedidosCubit(context.read())),
      BlocProvider(create: (context) => MesasCubit(context.read())),
    ],
    child: const AppWidget(),
  );

  runApp(app);
}
