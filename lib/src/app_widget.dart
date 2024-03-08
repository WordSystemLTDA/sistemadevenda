import 'package:app/src/modulos/login/ui/login_page.dart';
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
      initialRoute: "inicio",
      routes: {
        'inicio': (context) {
          return const LoginPage();
        }
      },
      // routerConfig: Modular.routerConfig,
    );
  }
}
