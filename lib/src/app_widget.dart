import 'package:app/src/features/home/ui/home_page.dart';
import 'package:app/src/features/mesas/ui/mesas_page.dart';
import 'package:app/src/features/pedidos/ui/pedidos_page.dart';
import 'package:app/src/features/produto/ui/produto_page.dart';
import 'package:app/src/features/produtos/ui/produtos_page.dart';

import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';
import 'shared/themes/themes.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      routes: {
        '/': (context) => const HomePage(),
        '/mesas': (context) => const MesasPage(),
        '/pedidos': (context) => const PedidosPage(),
        '/produtos': (context) => const ProdutosPage(),
        '/produto': (context) => const ProdutoPage(),
      },
      onGenerateRoute: (settings) {
        if (settings.name == "/") {
          return PageTransition(
            child: const HomePage(),
            type: PageTransitionType.rightToLeft,
          );
        } else if (settings.name == "/mesas") {
          return PageTransition(
            child: const MesasPage(),
            type: PageTransitionType.rightToLeft,
          );
        } else if (settings.name == "/pedidos") {
          return PageTransition(
            child: const PedidosPage(),
            type: PageTransitionType.rightToLeft,
          );
        } else if (settings.name == "/produtos") {
          return PageTransition(
            child: const ProdutosPage(),
            type: PageTransitionType.rightToLeft,
          );
        } else if (settings.name == "/produto") {
          return PageTransition(
            child: const ProdutoPage(),
            type: PageTransitionType.rightToLeft,
          );
        }

        return null;

        // Unknown route
        // return MaterialPageRoute(builder: (_) => UnknownPage());
      },
    );
  }
}
