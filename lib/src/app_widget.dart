import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: usuarioProvedor,
      builder: (context, snapshot) {
        return MaterialApp(
          title: 'Garçom',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
          ),
          // themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(),
          debugShowCheckedModeBanner: false,
          initialRoute: "login",
          routes: {
            'login': (context) {
              return const PaginaLogin();
            }
          },
        );
      },
    );
  }
}
