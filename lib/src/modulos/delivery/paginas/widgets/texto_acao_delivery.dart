import 'package:flutter/material.dart';

class TextoAcaoDelivery extends StatefulWidget {
  final String titulo, rotulo, inicial;
  const TextoAcaoDelivery(
      {super.key,
      required this.titulo,
      required this.rotulo,
      this.inicial = ''});
  @override
  State<TextoAcaoDelivery> createState() => _TextoAcaoDeliveryState();
}

class _TextoAcaoDeliveryState extends State<TextoAcaoDelivery> {
  late final _texto = TextEditingController(text: widget.inicial);
  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: Text(widget.titulo),
        content: TextField(
            controller: _texto,
            autofocus: true,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: widget.rotulo)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Voltar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, _texto.text.trim()),
              child: const Text('Enviar')),
        ],
      );
}
