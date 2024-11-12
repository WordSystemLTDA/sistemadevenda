import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PaginaPosPreCadastro extends StatefulWidget {
  const PaginaPosPreCadastro({super.key});

  @override
  State<PaginaPosPreCadastro> createState() => _PaginaPosPreCadastroState();
}

class _PaginaPosPreCadastroState extends State<PaginaPosPreCadastro> {
  void _onPopInvoked(bool didPop) {
    if (didPop) {
      return;
    }

    Navigator.pop(context);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        _onPopInvoked(didPop);
      },
      child: Scaffold(
        body: Column(
          children: [
            SizedBox(width: MediaQuery.of(context).size.width),
            const Spacer(),
            Lottie.asset(
              'assets/lotties/sucesso.json',
              width: 145,
              height: 145,
              fit: BoxFit.fill,
              repeat: false,
            ),
            const SizedBox(height: 10),
            const Text(
              'Cadastrado com Sucesso. Entraremos em contato em Breve!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              style: ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll<Color>(Colors.red),
                foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
                shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5.0),
                  ),
                ),
              ),
              onPressed: () => _onPopInvoked(false),
              child: const Text('Retornar para Login'),
            ),
            const SizedBox(height: 45),
          ],
        ),
      ),
    );
  }
}
