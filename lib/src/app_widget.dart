import 'package:app/src/modulos/login/ui/pagina_login.dart';
import 'package:flutter/material.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      initialRoute: "login",
      routes: {
        'login': (context) {
          return const PaginaLogin();
        }
      },
      // routerConfig: Modular.routerConfig,
    );
  }
}
