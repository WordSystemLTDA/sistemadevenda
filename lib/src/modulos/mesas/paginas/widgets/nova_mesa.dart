import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class NovaMesa extends StatefulWidget {
  final bool editar;
  final String? nome;
  final String? id;
  final String? codigo;
  final Function() aoSalvar;
  const NovaMesa({super.key, this.nome, this.id, this.codigo, required this.editar, required this.aoSalvar});

  @override
  State<NovaMesa> createState() => _NovaMesaState();
}

class _NovaMesaState extends State<NovaMesa> {
  final ProvedorMesas _state = Modular.get<ProvedorMesas>();

  final nomeController = TextEditingController();
  final codigoController = TextEditingController();

  @override
  void initState() {
    super.initState();

    if (widget.editar) {
      nomeController.text = widget.nome!;
      codigoController.text = widget.codigo!;
    }
  }

  @override
  void dispose() {
    codigoController.dispose();
    nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Padding(
        padding: EdgeInsets.only(left: 15, right: 15, bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            TextField(
              controller: codigoController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(13),
                label: Text('Código'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(13),
                label: Text('Nome'),
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
                    await _state.editarMesa(widget.id!, nomeController.text, codigoController.text).then((sucesso) {
                      if (sucesso) {
                        widget.aoSalvar();
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: sucesso ? Text(widget.editar ? 'Mesa Editada' : 'Mesa Cadastrada') : const Text('Ocorreu um erro'),
                          showCloseIcon: true,
                        ));
                      }
                    });
                  } else {
                    await _state.cadastrarMesa(nomeController.text, codigoController.text).then((sucesso) {
                      if (sucesso) {
                        widget.aoSalvar();
                      }

                      if (context.mounted) {
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
