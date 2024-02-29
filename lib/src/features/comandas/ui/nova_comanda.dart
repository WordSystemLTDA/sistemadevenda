import 'package:app/src/features/comandas/interactor/states/comandas_state.dart';
import 'package:flutter/material.dart';

class NovaComanda extends StatefulWidget {
  final bool editar;
  final String? nome;
  const NovaComanda({super.key, this.nome, required this.editar});

  @override
  State<NovaComanda> createState() => _NovaComandaState();
}

class _NovaComandaState extends State<NovaComanda> {
  final ComandasState _state = ComandasState();

  final nomeController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.editar) {
      nomeController.text = widget.nome!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: EdgeInsets.only(left: 10, right: 10, bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(13),
                label: Text('Digite o Nome'),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(Theme.of(context).colorScheme.primary),
                  side: const MaterialStatePropertyAll(BorderSide.none),
                  shape: const MaterialStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                  ),
                  foregroundColor: const MaterialStatePropertyAll(Colors.white),
                  textStyle: const MaterialStatePropertyAll(TextStyle(fontSize: 18)),
                ),
                onPressed: () async {
                  if (nomeController.text.isEmpty) return;

                  final res = await _state.cadastrarComanda(nomeController.text);

                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: res ? const Text('Comanda Cadastrada') : const Text('Ocorreu um erro'),
                      showCloseIcon: true,
                    ));
                  }
                },
                child: const SizedBox(
                  height: 50,
                  child: Center(child: Text('Salvar')),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
