import 'package:app/src/essencial/utils/enviar_pedido.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinho extends StatefulWidget {
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;
  final String idCliente;

  const PaginaCarrinho({
    super.key,
    required this.idComanda,
    required this.idComandaPedido,
    required this.idCliente,
    required this.idMesa,
  });

  @override
  State<PaginaCarrinho> createState() => _PaginaCarrinhoState();
}

class _PaginaCarrinhoState extends State<PaginaCarrinho> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  bool isLoading = false;
  Modeloworddadoscardapio? dados;

  @override
  void initState() {
    super.initState();
    listar();
  }

  void listar() async {
    await carrinhoProvedor.listarComandasPedidos(widget.idComandaPedido);
    await servicoCardapio.listarPorId(widget.idComandaPedido, TipoCardapio.comanda).then((value) {
      dados = value;
    });
  }

  void removerTodosItensCarrinho() async {
    List<String> listaIdItemComanda = [];
    for (int index = 0; index < carrinhoProvedor.itensCarrinho.listaComandosPedidos.length; index++) {
      listaIdItemComanda.add(carrinhoProvedor.itensCarrinho.listaComandosPedidos[index].id);
    }

    await carrinhoProvedor.removerComandasPedidos(widget.idComanda, widget.idMesa, listaIdItemComanda).then((sucesso) {
      if (mounted) {
        carrinhoProvedor.listarComandasPedidos(widget.idComandaPedido);
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
                          Row(
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
                                  removerTodosItensCarrinho();
                                },
                                child: const Text('excluir'),
                              ),
                            ],
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

                  await servicoCardapio
                      .inserirProdutosComanda(
                    carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                    widget.idMesa,
                    widget.idComandaPedido,
                    widget.idComanda,
                    widget.idCliente,
                  )
                      .then((resposta) {
                    var (sucesso, mensagem) = resposta;

                    if (sucesso) {
                      removerTodosItensCarrinho();
                      EnviarPedido.enviarPedido(
                        tipo: '1',
                        nomeTitulo: "Comanda ${widget.idComanda}",
                        numeroPedido: dados!.numeroPedido!,
                        nomeCliente: dados!.nomeCliente!,
                        nomeEmpresa: dados!.nomeEmpresa!,
                        produtosNovos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                      );

                      if (context.mounted) {
                        if (widget.idComanda != '0') {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        } else if (widget.idMesa != '0') {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        }
                      }

                      return;
                    }

                    if (context.mounted) {
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
                    ? SizedBox(
                        width: width - 70,
                        height: 50,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ))
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
                    idComandaPedido: widget.idComandaPedido,
                    idComanda: widget.idComanda,
                    idMesa: widget.idMesa,
                    value: carrinhoProvedor.itensCarrinho,
                    setarQuantidade: (increase) {
                      if (increase) {
                        setState(() {
                          item.quantidade = item.quantidade! + 1;
                        });

                        double precoTotal = 0;
                        carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) {
                          precoTotal += double.parse(e.valorVenda) * e.quantidade!;

                          e.adicionais.map((el) => precoTotal += double.parse(el.valor) * el.quantidade).toList();
                        }).toList();

                        setState(() => carrinhoProvedor.itensCarrinho.precoTotal = precoTotal);
                      } else {
                        setState(() {
                          item.quantidade = item.quantidade! - 1;
                        });

                        double precoTotal = 0;
                        carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) {
                          precoTotal += double.parse(e.valorVenda) * e.quantidade!;

                          e.adicionais.map((el) => precoTotal += double.parse(el.valor) * el.quantidade).toList();
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
