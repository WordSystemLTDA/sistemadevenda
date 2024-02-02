import 'package:app/src/app_module.dart';
import 'package:app/src/app_widget.dart';
import 'package:app/src/features/cardapio/interactor/states/produtos_state.dart';

import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(
    // MultiProvider(
    // providers: [
    //   // ChangeNotifierProvider(create: (context) => ProdutoState()),
    //   // ChangeNotifierProvider()
    // ],
    // child:
    ModularApp(
      module: AppModule(),
      child: const AppWidget(),
    ),
    // )
  );
}
