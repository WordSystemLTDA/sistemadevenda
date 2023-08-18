import 'package:app/src/features/login/interactor/cubit/autenticacao_cubit.dart';
import 'package:app/src/features/login/interactor/states/autenticacao_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_modular/flutter_modular.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AutenticacaoCubit _autenticacaoCubit = Modular.get<AutenticacaoCubit>();
  TextEditingController usuarioController = TextEditingController();
  TextEditingController senhaController = TextEditingController();

  final snackBarErroAutenticacao = SnackBar(
    content: const Text('Dados incorretos'),
    action: SnackBarAction(
      label: 'OK',
      onPressed: () {},
    ),
  );

  Widget _conteudoBotaoEntrar(state) {
    if (state is Carregando) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else {
      return const Text('Entrar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AutenticacaoCubit, AutenticacaoEstado>(
      bloc: _autenticacaoCubit,
      listener: (context, state) {
        if (state is Autenticado) {
          Modular.to.pushReplacementNamed('/inicio');
        } else if (state is AutenticacaoErro) {
          ScaffoldMessenger.of(context).showSnackBar(snackBarErroAutenticacao);
        }
      },
      builder: (context, state) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextField(
                    controller: usuarioController,
                    decoration: const InputDecoration(
                      labelText: "E-mail",
                      hintStyle: TextStyle(fontWeight: FontWeight.w300),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
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
                      onPressed: () {
                        _autenticacaoCubit.entrar(usuarioController.text, senhaController.text);
                      },
                      child: _conteudoBotaoEntrar(state),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
