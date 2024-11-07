import 'package:app/src/essencial/provedores/usuario/usuario_servico.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/inicio/paginas/pagina_inicio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaLogin extends StatefulWidget {
  const PaginaLogin({super.key});

  @override
  State<PaginaLogin> createState() => _PaginaLoginState();
}

class _PaginaLoginState extends State<PaginaLogin> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  final ServicoAutenticacao _service = Modular.get<ServicoAutenticacao>();

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

    if (mounted && !res) {
      setState(() => isLoading = !isLoading);
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Usuário ou Senha incorretos'),
        showCloseIcon: true,
      ));
      return;
    }

    if (mounted) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) {
          return const PaginaInicio();
        },
      ));
    }
  }

  void verificarLogin() async {
    var usuario = await UsuarioServico.pegarUsuario(context);

    if (usuario != null) {
      final sucesso = await _service.entrar(usuario.email, usuario.senha);

      if (sucesso) {
        if (mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (context) {
              return const PaginaInicio();
            },
          ));
        }
      }
    }

    setState(() {
      verificando = false;
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
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: verificando == true
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(height: 100),
                      Image.asset(
                        'assets/logo_funco_transparente.png',
                        width: 200,
                        height: 150,
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            width: 200,
                            height: 150,
                            child: Center(child: Icon(Icons.error)),
                          );
                        },
                      ),
                      const SizedBox(height: 25),
                      TextField(
                        controller: usuarioController,
                        onSubmitted: (a) => entrar(),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(13),
                          labelText: "Usuário",
                          hintStyle: TextStyle(fontWeight: FontWeight.w300),
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 20),
                      TextField(
                        controller: senhaController,
                        obscureText: true,
                        onSubmitted: (a) => entrar(),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.all(13),
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
                          style: ButtonStyle(
                            // backgroundColor: MaterialStatePropertyAll(Colors.green),
                            backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.inversePrimary),
                            side: const WidgetStatePropertyAll(BorderSide.none),
                            shape: const WidgetStatePropertyAll(
                              RoundedRectangleBorder(
                                borderRadius: BorderRadius.all(Radius.circular(5)),
                              ),
                            ),
                            // foregroundColor: const MaterialStatePropertyAll(Colors.white),
                            textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18)),
                          ),
                          onPressed: entrar,
                          child: isLoading ? const CircularProgressIndicator() : const Text('Entrar'),
                        ),
                      ),
                      const SizedBox(height: 5),
                      TextButton(
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const PaginaConfiguracao()));
                        },
                        child: const Text('Configurações'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
