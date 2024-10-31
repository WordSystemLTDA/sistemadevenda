import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class BottomEditarParcelamento extends StatefulWidget {
  final Function(String valor, String data) aoSalvar;
  final String valor;
  final String data;
  const BottomEditarParcelamento({super.key, required this.aoSalvar, required this.valor, required this.data});

  @override
  State<BottomEditarParcelamento> createState() => _BottomEditarParcelamentoState();
}

class _BottomEditarParcelamentoState extends State<BottomEditarParcelamento> {
  final _valorController = TextEditingController();
  final _dataController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _valorController.text = widget.valor;
    _dataController.text = widget.data;
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
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Editar Parcela', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(label: Text('Valor')),
                controller: _valorController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.deny(',', replacementString: '.'),
                  FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d{0,2})')),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                decoration: const InputDecoration(label: Text('Data')),
                controller: _dataController,
                readOnly: true,
                onTap: () async {
                  final data = _dataController.text.split('/');

                  final DateTime? time = await showDatePicker(
                    context: context,
                    firstDate: DateTime(1950),
                    lastDate: DateTime(2100),
                    initialDate: data.length != 3 ? DateTime.now() : DateTime.parse('${data[2]}-${data[1]}-${data[0]}'),
                  );

                  if (time != null) {
                    _dataController.text = DateFormat('dd/MM/yyyy').format(time).toString();
                  }
                },
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
                      final data = _dataController.text.split('/');

                      widget.aoSalvar(_valorController.text, data.length == 3 ? '${data[2]}-${data[1]}-${data[0]}' : '0000-00-00');
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
    );
  }
}
