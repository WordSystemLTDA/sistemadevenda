import 'package:app/src/app_module.dart';
import 'package:app/src/app_widget.dart';
import 'package:app/src/managers/app_lifecycle_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/essencial/sincronizacao/banco_local.dart';
import 'package:app/src/essencial/api/conexao.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await iniciarAplicativo();
}

Future<void> iniciarAplicativo() async {
  try {
    BancoLocal.instancia ??= await BancoLocal.abrir();
    BancoLocal.instancia!.servidor = (await Apis().getConexao()).servidor;
  } catch (_) {
    runApp(const MaterialApp(home: FalhaArmazenamento()));
    return;
  }
  runApp(
    ModularApp(
      module: AppModule(),
      child: AppLifecycleObserver(
        child: const AppWidget(),
      ),
    ),
  );
}

class FalhaArmazenamento extends StatefulWidget {
  const FalhaArmazenamento({super.key});

  @override
  State<FalhaArmazenamento> createState() => _FalhaArmazenamentoState();
}

class _FalhaArmazenamentoState extends State<FalhaArmazenamento> {
  bool tentando = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.storage_outlined, size: 40),
        const SizedBox(height: 16),
        const Text('Nao foi possivel abrir os dados salvos. Verifique o espaco livre do aparelho e tente novamente.',
            textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: tentando ? null : () async {
            setState(() => tentando = true);
            await iniciarAplicativo();
            if (mounted) setState(() => tentando = false);
          },
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      ]),
    ))),
  );
}
