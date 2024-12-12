import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_acrescimo.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinho extends StatefulWidget {
  const PaginaCarrinho({
    super.key,
  });

  @override
  State<PaginaCarrinho> createState() => _PaginaCarrinhoState();
}

class _PaginaCarrinhoState extends State<PaginaCarrinho> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorFinalizarPagamento provedorFinalizarPagamento = Modular.get<ProvedorFinalizarPagamento>();
  final Server server = Modular.get<Server>();

  bool isLoading = false;
  Modeloworddadoscardapio? dados;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    listar();
  }

  void listar() async {
    await carrinhoProvedor.listarComandasPedidos();
    await servicoCardapio.listarPorId(provedorCardapio.id, provedorCardapio.tipo, "Não").then((value) {
      dados = value;
    });

    setState(() {
      carregando = false;
    });
  }

  void removerTodosItensCarrinho() async {
    List<String> listaIdItemComanda = [];
    for (int index = 0; index < carrinhoProvedor.itensCarrinho.listaComandosPedidos.length; index++) {
      listaIdItemComanda.add(carrinhoProvedor.itensCarrinho.listaComandosPedidos[index].id);
    }

    await carrinhoProvedor.removerComandasPedidos().then((sucesso) {
      if (mounted) {
        carrinhoProvedor.listarComandasPedidos();
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
                                child: const Text('Excluir'),
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
        floatingActionButton: (carregando || carrinhoProvedor.itensCarrinho.listaComandosPedidos.isEmpty)
            ? null
            : FloatingActionButton.extended(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                onPressed: () async {
                  setState(() => isLoading = !isLoading);

                  provedorFinalizarPagamento.idVenda = provedorCardapio.id;
                  provedorFinalizarPagamento.valor = carrinhoProvedor.itensCarrinho.precoTotal;

                  if (provedorCardapio.tipo == TipoCardapio.balcao) {
                    setState(() => isLoading = !isLoading);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        settings: const RouteSettings(name: 'PaginaFinalizarAcrescimo'),
                        builder: (context) => const PaginaFinalizarAcrescimo(),
                      ),
                    );
                  } else if (provedorCardapio.tipo == TipoCardapio.mesa) {
                    await servicoCardapio
                        .inserirProdutosMesa(
                      carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                      provedorCardapio.idMesa,
                      provedorCardapio.id,
                      provedorCardapio.idCliente,
                    )
                        .then((resposta) {
                      var (sucesso, mensagem) = resposta;

                      if (sucesso) {
                        provedorMesas.listarMesas('');
                        server.write(jsonEncode({
                          'tipo': 'Mesa',
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));

                        removerTodosItensCarrinho();
                        Impressao.comprovanteDePedido(
                          tipodeentrega: provedorCardapio.tipodeentrega,
                          tipoTela: provedorCardapio.tipo,
                          comanda: dados!.nome!,
                          numeroPedido: dados!.numeroPedido!,
                          nomeCliente: dados!.nomeCliente!,
                          nomeEmpresa: dados!.nomeEmpresa!,
                          produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                          local: '',
                        );

                        if (context.mounted) {
                          Navigator.popUntil(context, ModalRoute.withName('PaginaMesas'));
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
                  } else {
                    await servicoCardapio
                        .inserirProdutosComanda(
                      carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                      provedorCardapio.idMesa,
                      provedorCardapio.id,
                      provedorCardapio.idComanda,
                      provedorCardapio.idCliente,
                    )
                        .then((resposta) {
                      var (sucesso, mensagem) = resposta;

                      if (sucesso) {
                        // final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();

                        provedorComanda.listarComandas('');
                        server.write(jsonEncode({
                          'tipo': 'Comanda',
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));

                        removerTodosItensCarrinho();
                        Impressao.comprovanteDePedido(
                          tipodeentrega: provedorCardapio.tipodeentrega,
                          tipoTela: provedorCardapio.tipo,
                          comanda: dados!.nome!,
                          numeroPedido: dados!.numeroPedido!,
                          nomeCliente: dados!.nomeCliente!,
                          nomeEmpresa: dados!.nomeEmpresa!,
                          produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                          local: '',
                        );

                        if (context.mounted) {
                          Navigator.popUntil(context, ModalRoute.withName('PaginaComandas'));
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
                  }
                },
                label: isLoading
                    ? SizedBox(
                        width: width - 70,
                        height: 50,
                        child: const Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
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
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : carrinhoProvedor.itensCarrinho.listaComandosPedidos.isEmpty
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
                        idComanda: provedorCardapio.idComanda,
                        idMesa: provedorCardapio.idMesa,
                        value: carrinhoProvedor.itensCarrinho,
                        setarQuantidade: (increase) {
                          if (increase) {
                            setState(() {
                              item.quantidade = item.quantidade! + 1;
                            });

                            double precoTotal = 0;
                            carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) {
                              precoTotal += double.parse(e.valorVenda) * e.quantidade!;

                              // e.adicionais.map((el) => precoTotal += double.parse(el.valor) * el.quantidade).toList();
                            }).toList();

                            setState(() => carrinhoProvedor.itensCarrinho.precoTotal = precoTotal);
                          } else {
                            setState(() {
                              item.quantidade = item.quantidade! - 1;
                            });

                            double precoTotal = 0;
                            carrinhoProvedor.itensCarrinho.listaComandosPedidos.map((e) {
                              precoTotal += double.parse(e.valorVenda) * e.quantidade!;

                              // e.adicionais.map((el) => precoTotal += double.parse(el.valor) * el.quantidade).toList();
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
