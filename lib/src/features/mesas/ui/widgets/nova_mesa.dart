import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';
import 'package:flutter/material.dart';

class NovaMesa extends StatefulWidget {
  final bool editar;
  final String? nome;
  final String? id;
  const NovaMesa({super.key, this.nome, this.id, required this.editar});

  @override
  State<NovaMesa> createState() => _NovaMesaState();
}

class _NovaMesaState extends State<NovaMesa> {
  final MesaState _state = MesaState();

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

                  if (widget.editar) {
                    await _state.editarMesa(widget.id!, nomeController.text).then((sucesso) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: sucesso ? Text(widget.editar ? 'Mesa Editada' : 'Mesa Cadastrada') : const Text('Ocorreu um erro'),
                          showCloseIcon: true,
                        ));
                      }
                    });
                  } else {
                    await _state.cadastrarMesa(nomeController.text).then((sucesso) {
                      if (mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: sucesso ? Text(widget.editar ? 'Mesa Editada' : 'Mesa Cadastrada') : const Text('Ocorreu um erro'),
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
