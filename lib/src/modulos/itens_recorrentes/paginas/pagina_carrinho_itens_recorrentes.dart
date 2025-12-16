import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinhoItensRecorrentes extends StatefulWidget {
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;
  final String idCliente;

  const PaginaCarrinhoItensRecorrentes({
    super.key,
    required this.idComanda,
    required this.idComandaPedido,
    required this.idMesa,
    required this.idCliente,
  });

  @override
  State<PaginaCarrinhoItensRecorrentes> createState() => _PaginaCarrinhoItensRecorrentesState();
}

class _PaginaCarrinhoItensRecorrentesState extends State<PaginaCarrinhoItensRecorrentes> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorFinalizarPagamento provedorFinalizarPagamento = Modular.get<ProvedorFinalizarPagamento>();
  final ProvedorItensRecorrentes provedorItensRecorrentes = Modular.get<ProvedorItensRecorrentes>();
  final Server server = Modular.get<Server>();

  bool isLoading = false;
  Modeloworddadoscardapio? dados;
  bool carregando = false;

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

  Future<void> removerTodosItensCarrinho() async {
    // aqui
    await provedorItensRecorrentes.removerComandasPedidos(widget.idComandaPedido);
    // List<String> listaIdItemComanda = [];
    // for (int index = 0; index < carrinhoProvedor.itensCarrinho.listaComandosPedidos.length; index++) {
    //   listaIdItemComanda.add(carrinhoProvedor.itensCarrinho.listaComandosPedidos[index].id);
    // }

    // await carrinhoProvedor.removerComandasPedidos().then((sucesso) {
    //   if (mounted) {
    //     carrinhoProvedor.listarComandasPedidos();
    //   }

    //   if (sucesso) return;

    //   if (mounted) {
    //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //       content: Text('Ocorreu um erro'),
    //       showCloseIcon: true,
    //     ));
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: provedorItensRecorrentes,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Carrinho'),
          // title: const Text('Carrinho Itens Recorrentes'),
          centerTitle: true,
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          actions: [
            if (provedorItensRecorrentes.itensCarrinho.isNotEmpty) ...[
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return AlertDialog(
                        title: const Text('Exclusão de Produtos'),
                        content: const SingleChildScrollView(
                          child: ListBody(
                            children: <Widget>[
                              Text('Deseja realmente excluir todos os produtos no carrinho?'),
                            ],
                          ),
                        ),
                        actions: <Widget>[
                          TextButton(
                            child: const Text('Cancelar'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton(
                            child: const Text('Excluir'),
                            onPressed: () async {
                              await removerTodosItensCarrinho();
                              if (context.mounted) {
                                provedorItensRecorrentes.listarComandasPedidos(widget.idComandaPedido);
                                Navigator.pop(context);
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.delete),
              ),
            ]
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: (carregando || provedorItensRecorrentes.itensCarrinho.isEmpty)
            ? null
            : FloatingActionButton.extended(
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(5)),
                ),
                onPressed: () async {
                  setState(() => isLoading = !isLoading);

                  // provedorFinalizarPagamento.idVenda = provedorCardapio.id;
                  // provedorFinalizarPagamento.valor = carrinhoProvedor.itensCarrinho.precoTotal;

                  // if (provedorCardapio.tipo == TipoCardapio.balcao) {
                  //   setState(() => isLoading = !isLoading);
                  //   Navigator.push(
                  //     context,
                  //     MaterialPageRoute(
                  //       settings: const RouteSettings(name: 'PaginaFinalizarAcrescimo'),
                  //       builder: (context) => const PaginaFinalizarAcrescimo(),
                  //     ),
                  //   );
                  // } else
                  // if (provedorCardapio.tipo == TipoCardapio.mesa) {
                  if (widget.idMesa != '0') {
                    await servicoCardapio
                        .inserirProdutosMesa(
                      provedorItensRecorrentes.itensCarrinho,
                      widget.idMesa,
                      widget.idComandaPedido,
                      widget.idCliente,
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
                          // TODO: tipodeentrega
                          tipodeentrega: '',
                          tipoTela: TipoCardapio.mesa,
                          comanda: dados?.nome ?? '',
                          numeroPedido: dados?.numeroPedido ?? '',
                          // comanda: dados!.nome!,
                          // numeroPedido: dados!.numeroPedido!,
                          nomeCliente: (dados?.nomeCliente ?? 'Sem Cliente') == 'Sem Cliente' && (dados?.observacaoDoPedido ?? '').isNotEmpty
                              ? (dados?.observacaoDoPedido ?? '')
                              : (dados?.nomeCliente ?? 'Sem Cliente'),
                          nomeEmpresa: dados?.nomeEmpresa ?? '',
                          // nomeEmpresa: dados!.nomeEmpresa!,
                          produtos: provedorItensRecorrentes.itensCarrinho,
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
                      provedorItensRecorrentes.itensCarrinho,
                      widget.idMesa,
                      widget.idComandaPedido,
                      widget.idComanda,
                      widget.idCliente,
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
                          // TODO: tipodeentrega
                          tipodeentrega: '',
                          tipoTela: TipoCardapio.comanda,
                          comanda: dados?.nome ?? '',
                          numeroPedido: dados?.numeroPedido ?? '',
                          // comanda: dados!.nome!,
                          // numeroPedido: dados!.numeroPedido!,
                          // nomeCliente: dados!.nomeCliente!,
                          nomeCliente: (dados?.nomeCliente ?? 'Sem Cliente') == 'Sem Cliente' && (dados?.observacaoDoPedido ?? '').isNotEmpty
                              ? (dados?.observacaoDoPedido ?? '')
                              : (dados?.nomeCliente ?? 'Sem Cliente'),
                          nomeEmpresa: dados?.nomeEmpresa ?? '',
                          // nomeEmpresa: dados!.nomeEmpresa!,
                          produtos: provedorItensRecorrentes.itensCarrinho,
                          local: dados?.nomeMesa ?? '',
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
                            Text(provedorItensRecorrentes.precoTotal.obterReal()),
                          ],
                        ),
                      ),
              ),
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : provedorItensRecorrentes.itensCarrinho.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 100, child: Center(child: Text('Não há itens na Comanda'))),
                    ],
                  )
                : ListView.builder(
                    itemCount: provedorItensRecorrentes.itensCarrinho.length,
                    padding: const EdgeInsets.only(bottom: 150, left: 10, right: 10, top: 10),
                    itemBuilder: (context, index) {
                      final item = provedorItensRecorrentes.itensCarrinho[index];

                      return CardCarrinhoItensRecorrentes(
                        item: item,
                        idComanda: widget.idComanda,
                        idComandaPedido: widget.idComandaPedido,
                        idMesa: widget.idMesa,
                        index: index,
                        value: null,
                        // value: carrinhoProvedor.itensCarrinho,
                        setarQuantidade: (increase) async {
                          if (increase) {
                            await provedorItensRecorrentes.setarItemCarrinho(widget.idComandaPedido, index, item.quantidade! + 1);
                            if (context.mounted) {
                              provedorItensRecorrentes.listarComandasPedidos(widget.idComandaPedido);
                            }
                          } else {
                            await provedorItensRecorrentes.setarItemCarrinho(widget.idComandaPedido, index, item.quantidade! - 1);
                            if (context.mounted) {
                              provedorItensRecorrentes.listarComandasPedidos(widget.idComandaPedido);
                            }
                          }
                        },
                      );
                    },
                  ),
      ),
    );
  }
}
