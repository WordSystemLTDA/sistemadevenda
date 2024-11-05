import 'package:flutter/material.dart';

class ModalCancelarVenda extends StatefulWidget {
  final Future<void> Function(String justificativa) aoSalvar;
  const ModalCancelarVenda({super.key, required this.aoSalvar});

  @override
  State<ModalCancelarVenda> createState() => _ModalCancelarVendaState();
}

class _ModalCancelarVendaState extends State<ModalCancelarVenda> {
  final TextEditingController justificativaController = TextEditingController();

  bool salvando = false;

  @override
  void dispose() {
    justificativaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      title: const Text('Cancelar Venda'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Deseja realmente cancelar esta Venda?'),
          const SizedBox(height: 20),
          TextField(
            controller: justificativaController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Justificativa',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Fechar'),
        ),
        TextButton(
          onPressed: () async {
            setState(() {
              salvando = true;
            });

            await widget.aoSalvar(justificativaController.text);

            setState(() {
              salvando = false;
            });

            if (context.mounted) {
              Navigator.pop(context);
            }
          },
          style: const ButtonStyle(
            backgroundColor: WidgetStatePropertyAll(Colors.red),
            foregroundColor: WidgetStatePropertyAll(Colors.white),
          ),
          child: salvando ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Cancelar'),
        ),
      ],
    );
  }
}
