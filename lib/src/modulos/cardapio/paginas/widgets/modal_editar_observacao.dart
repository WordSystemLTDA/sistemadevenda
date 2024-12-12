import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ModalEditarObservacao extends StatefulWidget {
  final String idProduto;
  final String observacao;
  const ModalEditarObservacao({super.key, required this.idProduto, required this.observacao});

  @override
  State<ModalEditarObservacao> createState() => _ModalEditarObservacaoState();
}

class _ModalEditarObservacaoState extends State<ModalEditarObservacao> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();

  TextEditingController observacoesController = TextEditingController();

  @override
  void initState() {
    observacoesController.text = widget.observacao;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Observação do Item', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 20),
          SizedBox(
            height: 150,
            child: TextField(
              maxLines: 4,
              controller: observacoesController,
              decoration: const InputDecoration(
                hintText: 'Observação',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ButtonStyle(
                backgroundColor: const WidgetStatePropertyAll(Colors.green),
                foregroundColor: const WidgetStatePropertyAll(Colors.white),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                )),
              ),
              onPressed: () {
                var item = carrinhoProvedor.itensCarrinho.listaComandosPedidos.where((element) => element.id == widget.idProduto).firstOrNull;

                setState(() {
                  item?.observacao = observacoesController.text;
                  item?.opcoesPacotesListaFinal = [
                    ...(item.opcoesPacotesListaFinal?.toList() ?? []).where((element) => element.id != 11),
                    ModeloOpcoesPacotes(
                      id: 11,
                      titulo: 'Observação',
                      tipo: 7,
                      obrigatorio: false,
                      dados: [
                        ModeloDadosOpcoesPacotes(
                          id: '0',
                          nome: observacoesController.text,
                          foto: '',
                          estaSelecionado: false,
                          excluir: false,
                        ),
                      ],
                    ),
                  ];
                });
                Navigator.pop(context);
              },
              child: const Text('Salvar'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
