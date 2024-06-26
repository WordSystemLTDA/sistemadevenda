import 'package:app/src/essencial/utils/enviar_pedido.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedor/provedor_carrinho.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinho extends StatefulWidget {
  final String idComanda;
  final String idMesa;
  const PaginaCarrinho({super.key, required this.idComanda, required this.idMesa});

  @override
  State<PaginaCarrinho> createState() => _PaginaCarrinhoState();
}

class _PaginaCarrinhoState extends State<PaginaCarrinho> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    carrinhoProvedor.listarComandasPedidos(widget.idComanda, widget.idMesa);
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: carrinhoProvedor,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Carrinho'),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (carrinhoProvedor.itensCarrinho.listaComandosPedidos.isNotEmpty) ...[
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => Dialog(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        shrinkWrap: true,
                        children: [
                          const Text(
                            'Deseja realmente excluir todos?',
                            style: TextStyle(fontSize: 20),
                          ),
                          const SizedBox(height: 15),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  child: const Text('Cancelar'),
                                ),
                                const SizedBox(width: 10),
                                TextButton(
                                  onPressed: () async {
                                    List<String> listaIdItemComanda = [];
                                    for (int index = 0; index < carrinhoProvedor.itensCarrinho.listaComandosPedidos.length; index++) {
                                      listaIdItemComanda.add(carrinhoProvedor.itensCarrinho.listaComandosPedidos[index].id);
                                    }

                                    await carrinhoProvedor.removerComandasPedidos(widget.idComanda, widget.idMesa, listaIdItemComanda).then((sucesso) {
                                      if (mounted) {
                                        carrinhoProvedor.listarComandasPedidos(widget.idComanda, widget.idMesa);
                                        Navigator.pop(context);
                                      }

                                      if (sucesso) return;

                                      if (mounted) {
                                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                          content: Text('Ocorreu um erro'),
                                          showCloseIcon: true,
                                        ));
                                      }
                                    });
                                  },
                                  child: const Text('excluir'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.delete),
              ),
            ]
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: carrinhoProvedor.itensCarrinho.listaComandosPedidos.isEmpty
            ? null
            : FloatingActionButton.extended(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                onPressed: () async {
                  setState(() => isLoading = !isLoading);

                  await carrinhoProvedor.lancarPedido(
                    widget.idMesa,
                    widget.idComanda,
                    carrinhoProvedor.itensCarrinho.precoTotal,
                    carrinhoProvedor.itensCarrinho.quantidadeTotal,
                    '',
                    [...carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) => e.id)],
                  ).then((sucesso) {
                    if (sucesso) {
                      EnviarPedido.enviarPedido('0', '0');
                      if (mounted) {
                        if (widget.idComanda != '0') {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        } else if (widget.idMesa != '0') {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        }
                      }
                      return;
                    }

                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Ocorreu um erro'),
                        showCloseIcon: true,
                      ));
                    }
                  }).whenComplete(() {
                    setState(() => isLoading = !isLoading);
                  });
                },
                label: isLoading
                    ? SizedBox(width: width - 70, child: const CircularProgressIndicator())
                    : SizedBox(
                        width: width - 70,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Finalizar'),
                            const SizedBox(width: 10),
                            Text(carrinhoProvedor.itensCarrinho.precoTotal.obterReal()),
                          ],
                        ),
                      ),
              ),
        body: carrinhoProvedor.itensCarrinho.listaComandosPedidos.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 100, child: Center(child: Text('Não há itens na Comanda'))),
                ],
              )
            : ListView.builder(
                itemCount: carrinhoProvedor.itensCarrinho.listaComandosPedidos.length,
                padding: const EdgeInsets.only(bottom: 150, left: 10, right: 10, top: 10),
                itemBuilder: (context, index) {
                  final item = carrinhoProvedor.itensCarrinho.listaComandosPedidos[index];

                  return CardCarrinho(
                    item: item,
                    idComanda: widget.idComanda,
                    idMesa: widget.idMesa,
                    value: carrinhoProvedor.itensCarrinho,
                    setarQuantidade: (increase) {
                      if (increase) {
                        setState(() => item.quantidade++);

                        double precoTotal = 0;
                        carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) {
                          precoTotal += e.valor * e.quantidade;

                          e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                        }).toList();

                        setState(() => carrinhoProvedor.itensCarrinho.precoTotal = precoTotal);
                      } else {
                        setState(() => --item.quantidade);

                        double precoTotal = 0;
                        carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) {
                          precoTotal += e.valor * e.quantidade;

                          e.listaAdicionais.map((el) => precoTotal += el.valorAdicional * el.quantidade).toList();
                        }).toList();

                        setState(() => carrinhoProvedor.itensCarrinho.precoTotal = precoTotal);
                      }
                    },
                  );
                },
              ),
      ),
    );
  }
}
