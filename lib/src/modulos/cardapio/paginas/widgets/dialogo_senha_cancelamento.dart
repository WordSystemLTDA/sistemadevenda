import 'package:flutter/material.dart';

Future<String?> pedirSenhaCancelamentoItem({
  required BuildContext context,
  required String nomeItem,
  required String nomeDestino,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _DialogSenhaCancelamento(
      nomeItem: nomeItem,
      nomeDestino: nomeDestino,
    ),
  );
}

class _DialogSenhaCancelamento extends StatefulWidget {
  final String nomeItem;
  final String nomeDestino;

  const _DialogSenhaCancelamento({
    required this.nomeItem,
    required this.nomeDestino,
  });

  @override
  State<_DialogSenhaCancelamento> createState() =>
      _DialogSenhaCancelamentoState();
}

class _DialogSenhaCancelamentoState extends State<_DialogSenhaCancelamento> {
  final TextEditingController _controller = TextEditingController();
  String _erro = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirmar() {
    final senha = _controller.text.trim();
    if (senha.isEmpty) {
      setState(() => _erro = 'Informe a senha Admin.');
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context, rootNavigator: true).pop(senha);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.delete_outline_rounded, color: cs.error),
      title: const Text('Excluir Item'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.nomeItem,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Text(
              'Digite a senha Admin para confirmar o cancelamento.',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.print_outlined, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Será impresso em: ${widget.nomeDestino}',
                      style: TextStyle(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              autofocus: true,
              obscureText: true,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: 'Senha Admin',
                errorText: _erro.isEmpty ? null : _erro,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _confirmar(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _confirmar,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Confirmar exclusão'),
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
        ),
      ],
    );
  }
}
