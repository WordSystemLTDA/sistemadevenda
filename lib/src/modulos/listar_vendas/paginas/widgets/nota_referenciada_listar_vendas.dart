import 'package:app/src/essencial/widgets/custom_text_field.dart';
import 'package:flutter/material.dart';

class NotaReferenciadaListarVendas extends StatefulWidget {
  final TextEditingController tipoReferenciaController;
  final TextEditingController nomeTipoReferenciaController;
  final TextEditingController chaveAcessoController;

  const NotaReferenciadaListarVendas({
    super.key,
    required this.tipoReferenciaController,
    required this.nomeTipoReferenciaController,
    required this.chaveAcessoController,
  });

  @override
  State<NotaReferenciadaListarVendas> createState() => _NotaReferenciadaListarVendasState();
}

class _NotaReferenciadaListarVendasState extends State<NotaReferenciadaListarVendas> {
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
                child: SearchAnchor(
                  builder: (context, controller) {
                    return CustomTextField(
                      titulo: const Text('Tipo de Referencia', style: TextStyle(fontSize: 14)),
                      readOnly: true,
                      controller: widget.nomeTipoReferenciaController,
                      hintText: 'Selecione um Tipo de Referencia',
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) {
                    final res = [];

                    return [
                      ...res.map(
                        (e) => SizedBox(
                          height: 100,
                          child: Card(
                            child: Center(
                              child: ListTile(
                                onTap: () {
                                  widget.nomeTipoReferenciaController.text;
                                  widget.tipoReferenciaController.text;
                                },
                                leading: const Icon(Icons.person),
                                title: Text(e),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  titulo: const Text('Chave de Acesso', style: TextStyle(fontSize: 14)),
                  controller: widget.chaveAcessoController,
                  hintText: 'Chave de Acesso',
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
