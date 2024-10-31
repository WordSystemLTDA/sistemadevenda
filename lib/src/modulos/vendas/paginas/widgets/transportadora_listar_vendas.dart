import 'package:app/src/essencial/widgets/custom_text_field.dart';
import 'package:app/src/modulos/vendas/servicos/servicos_listar_vendas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class TransportadoraListarVendas extends StatefulWidget {
  final TextEditingController transportadoraController;
  final TextEditingController nomeTransportadoraController;
  final TextEditingController fretePorContaController;
  final TextEditingController nomeFretePorContaController;
  final TextEditingController placaDoVeiculoController;
  final TextEditingController ufController;
  final TextEditingController quantidadeController;
  final TextEditingController especieController;
  final TextEditingController marcaController;
  final TextEditingController numeracaoController;
  final TextEditingController pesoBrutoController;
  final TextEditingController pesoLiquidoController;

  const TransportadoraListarVendas({
    super.key,
    required this.transportadoraController,
    required this.nomeTransportadoraController,
    required this.fretePorContaController,
    required this.nomeFretePorContaController,
    required this.placaDoVeiculoController,
    required this.ufController,
    required this.quantidadeController,
    required this.especieController,
    required this.marcaController,
    required this.numeracaoController,
    required this.pesoBrutoController,
    required this.pesoLiquidoController,
  });

  @override
  State<TransportadoraListarVendas> createState() => _TransportadoraListarVendasState();
}

class _TransportadoraListarVendasState extends State<TransportadoraListarVendas> {
  final controller = TextEditingController();

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
                      titulo: const Text('Transportadora', style: TextStyle(fontSize: 14)),
                      readOnly: true,
                      controller: widget.nomeTransportadoraController,
                      hintText: 'Selecione uma Transportadora',
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) async {
                    final pesquisa = controller.text;

                    final res = await Modular.get<ServicosListarVendas>().listarTransportadoras(pesquisa);

                    return [
                      ...res.map((e) => SizedBox(
                            height: 80,
                            child: Card(
                              child: InkWell(
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                onTap: () {
                                  controller.closeView(e.nome.split(' - ').first);
                                  widget.nomeTransportadoraController.text = e.nome.split(' - ').first;
                                  widget.transportadoraController.text = e.id;
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(e.nome, style: const TextStyle(overflow: TextOverflow.ellipsis), maxLines: 1),
                                  subtitle: Text('ID: ${e.id}'),
                                ),
                              ),
                            ),
                          )),
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
                child: SearchAnchor(
                  builder: (context, controller) {
                    return CustomTextField(
                      titulo: const Text('Frete por Conta', style: TextStyle(fontSize: 14)),
                      readOnly: true,
                      controller: widget.nomeFretePorContaController,
                      hintText: 'Selecione um Frete',
                      onTap: () {
                        controller.openView();
                      },
                    );
                  },
                  suggestionsBuilder: (context, controller) async {
                    final pesquisa = controller.text;

                    final res = await Modular.get<ServicosListarVendas>().listarFrete(pesquisa);

                    return [
                      ...res.map((e) => SizedBox(
                            height: 80,
                            child: Card(
                              child: InkWell(
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                                onTap: () {
                                  controller.closeView(e.nome);
                                  widget.nomeFretePorContaController.text = e.nome;
                                  widget.fretePorContaController.text = e.id;
                                },
                                child: ListTile(
                                  leading: const Icon(Icons.person),
                                  title: Text(e.nome, style: const TextStyle(overflow: TextOverflow.ellipsis), maxLines: 2),
                                  subtitle: Text('ID: ${e.id}'),
                                ),
                              ),
                            ),
                          )),
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
                  titulo: const Text('Placa do Veículo', style: TextStyle(fontSize: 14)),
                  controller: widget.placaDoVeiculoController,
                  hintText: 'Placa do Veículo',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: CustomTextField(
                  titulo: const Text('UF', style: TextStyle(fontSize: 14)),
                  controller: widget.ufController,
                  hintText: 'UF',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  titulo: const Text('Quantidade', style: TextStyle(fontSize: 14)),
                  controller: widget.quantidadeController,
                  hintText: 'Quantidade',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: CustomTextField(
                titulo: const Text('Espécie', style: TextStyle(fontSize: 14)),
                controller: widget.especieController,
                hintText: 'Espécie',
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  titulo: const Text('Marca', style: TextStyle(fontSize: 14)),
                  controller: widget.marcaController,
                  hintText: 'Marca',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: CustomTextField(
                titulo: const Text('Numeração', style: TextStyle(fontSize: 14)),
                controller: widget.numeracaoController,
                hintText: 'Numeração',
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  titulo: const Text('Peso Bruto', style: TextStyle(fontSize: 14)),
                  controller: widget.pesoBrutoController,
                  hintText: 'Peso Bruto',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                  child: CustomTextField(
                titulo: const Text('Peso Líquido', style: TextStyle(fontSize: 14)),
                controller: widget.pesoLiquidoController,
                hintText: 'Peso Líquido',
              )),
            ],
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}
