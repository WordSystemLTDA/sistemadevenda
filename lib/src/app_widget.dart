import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/tema/theme_controller.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/essencial/sincronizacao/pendencias_sincronizacao.dart';

UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
GlobalKey<NavigatorState>? navigatorKey = GlobalKey<NavigatorState>();

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    const appBarTheme = AppBarThemeData(
      actionsPadding:
          EdgeInsets.only(right: EstadoSincronizacao.espacoNoCabecalho),
    );
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: context.read<ThemeController>(),
      builder: (context, state, _) {
        return ListenableBuilder(
          listenable: usuarioProvedor,
          builder: (context, snapshot) {
            return MaterialApp(
              title: 'Garçom',
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                appBarTheme: appBarTheme,
              ),
              // themeMode: ThemeMode.dark,
              themeMode: state,
              darkTheme: ThemeData.dark().copyWith(appBarTheme: appBarTheme),
              debugShowCheckedModeBanner: false,
              initialRoute: "login",
              navigatorKey: navigatorKey,
              // O indicador fica fora do Navigator e precisa de Overlay para a legenda.
              builder: (context, child) => Overlay.wrap(
                child: Stack(children: [
                  child ?? const SizedBox.shrink(),
                  Positioned(
                    top: MediaQuery.paddingOf(context).top,
                    right: MediaQuery.paddingOf(context).right,
                    width: EstadoSincronizacao.espacoNoCabecalho,
                    height: kToolbarHeight,
                    child: Center(
                      child: EstadoSincronizacao(
                        navigatorKey: navigatorKey,
                        flutuante: true,
                      ),
                    ),
                  ),
                ]),
              ),
              routes: {
                'login': (context) {
                  return const PaginaLogin();
                }
              },
            );
          },
        );
      },
    );
  }
}
