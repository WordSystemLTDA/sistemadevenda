import 'package:app/src/modulos/comandas/interactor/states/comandas_state.dart';
import 'package:flutter/material.dart';

class NovaComanda extends StatefulWidget {
  final bool editar;
  final String? nome;
  final String? id;
  const NovaComanda({super.key, this.nome, this.id, required this.editar});

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
        padding: EdgeInsets.only(left: 15, right: 15, bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
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
                  backgroundColor: WidgetStateProperty.all(Theme.of(context).colorScheme.primary),
                  side: const WidgetStatePropertyAll(BorderSide.none),
                  shape: const WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(5)),
                    ),
                  ),
                  foregroundColor: const WidgetStatePropertyAll(Colors.white),
                  textStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 18)),
                ),
                onPressed: () async {
                  if (nomeController.text.isEmpty) return;

                  if (widget.editar) {
                    await _state.editarComanda(widget.id!, nomeController.text).then((sucesso) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: sucesso ? Text(widget.editar ? 'Comanda Editada' : 'Comanda Cadastrada') : const Text('Ocorreu um erro'),
                          showCloseIcon: true,
                        ));
                      }
                    });
                  } else {
                    await _state.cadastrarComanda(nomeController.text).then((sucesso) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: sucesso ? Text(widget.editar ? 'Comanda Editada' : 'Comanda Cadastrada') : const Text('Ocorreu um erro'),
                          showCloseIcon: true,
                        ));
                      }
                    });
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
