import 'package:app/src/features/login/data/services/autenticacao_service_impl.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  final AutenticacaoServiceImpl _service = AutenticacaoServiceImpl();

  var verificando = true;
  var isLoading = false;

  void entrar() async {
    if (usuarioController.text.isEmpty || senhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Usuário e Senha são obrigatórios'),
        showCloseIcon: true,
      ));
      return;
    }
    setState(() => isLoading = !isLoading);
    final res = await _service.entrar(usuarioController.text, senhaController.text);
    setState(() => isLoading = !isLoading);
    if (!res) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Usuário ou Senha incorretos'),
        showCloseIcon: true,
      ));
      return;
    }

    Modular.to.pushNamed('/inicio');
  }

  void verificarLogin() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    bool logado = prefs.containsKey('usuario');

    // Future.delayed(const Duration(seconds: 2)).then((value) => {
    //       if (logado)
    //         {}
    //       else
    //         {
    //           setState(() {
    //             verificando = false;
    //           }),
    //         }
    //     });

    Future.delayed(const Duration(seconds: 2)).then((value) {
      if (logado) {
        Modular.to.pushNamed('/inicio');
      } else {
        setState(() {
          verificando = false;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    verificarLogin();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: InkWell(
        focusColor: Colors.transparent,
        splashColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: Center(
          child: verificando
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextField(
                        controller: usuarioController,
                        onSubmitted: (a) => entrar(),
                        decoration: const InputDecoration(
                          labelText: "Usuário",
                          hintStyle: TextStyle(fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: senhaController,
                        obscureText: true,
                        onSubmitted: (a) => entrar(),
                        decoration: const InputDecoration(
                          labelText: "Senha",
                          hintStyle: TextStyle(fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: const ButtonStyle(
                            backgroundColor: MaterialStatePropertyAll(Colors.green),
                            side: MaterialStatePropertyAll(BorderSide.none),
                            shape: MaterialStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                              ),
                            ),
                            foregroundColor: MaterialStatePropertyAll(Colors.white),
                            textStyle: MaterialStatePropertyAll(TextStyle(fontSize: 18)),
                          ),
                          onPressed: entrar,
                          child: isLoading ? const CircularProgressIndicator() : const Text('Entrar'),
                        ),
                      )
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
