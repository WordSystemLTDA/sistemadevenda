import 'package:app/src/essencial/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class ObsInternaListarVendas extends StatefulWidget {
  final TextEditingController observacoesInternaController;
  final TextEditingController dadosAdicionaisController;

  const ObsInternaListarVendas({
    super.key,
    required this.observacoesInternaController,
    required this.dadosAdicionaisController,
  });

  @override
  State<ObsInternaListarVendas> createState() => _ObsInternaListarVendasState();
}

class _ObsInternaListarVendasState extends State<ObsInternaListarVendas> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      focusColor: Colors.transparent,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  titulo: const Text('Observações Interna (Máx 2000 Caracteres)', style: TextStyle(fontSize: 14)),
                  controller: widget.observacoesInternaController,
                  maxLength: 2000,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  titulo: const Text('Dados Adicionais (Máx 2000 Caracteres)', style: TextStyle(fontSize: 14)),
                  controller: widget.dadosAdicionaisController,
                  maxLength: 2000,
                ),
              ),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
