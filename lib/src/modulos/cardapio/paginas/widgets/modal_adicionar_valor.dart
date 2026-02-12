import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ModalAdicionarValor extends StatefulWidget {
  final Function(String novoValor) aoSalvar;
  const ModalAdicionarValor({super.key, required this.aoSalvar});

  @override
  State<ModalAdicionarValor> createState() => _ModalAdicionarValorState();
}

class _ModalAdicionarValorState extends State<ModalAdicionarValor> {
  final _valorController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () {},
        child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, __) {
              return Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(10),
                        topRight: Radius.circular(10)),
                    color: Theme.of(context).scaffoldBackgroundColor,
                  ),
                  child: GestureDetector(
                    onTap: () {},
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Align(
                              alignment: Alignment.center,
                              child: Icon(Icons.drag_handle_sharp),
                            ),
                            const SizedBox(height: 20),
                            const Padding(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text('Adicionar Valor no Item',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600)),
                            ),
                            const Divider(),
                            const SizedBox(height: 20),
                            SizedBox(
                              height: 50,
                              child: TextField(
                                decoration: const InputDecoration(
                                    label: Text('Novo valor')),
                                controller: _valorController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                autofocus: true,
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(',',
                                      replacementString: '.'),
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'(^\d*\.?\d{0,2})')),
                                ],
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Fechar'),
                                ),
                                const SizedBox(width: 10),
                                ElevatedButton(
                                  onPressed: () {
                                    if ((double.tryParse(
                                                _valorController.text) ??
                                            0) <=
                                        0) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                        content: Text(
                                            'Valor deve ser maior que Zero!',
                                            textAlign: TextAlign.center),
                                        backgroundColor: Colors.red,
                                        behavior: SnackBarBehavior.floating,
                                      ));
                                      return;
                                    }

                                    widget.aoSalvar(_valorController.text);
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Salvar'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
      ),
    );
  }
}
