import 'dart:math' as math;

import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_adicionar_valor.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardProduto extends StatefulWidget {
  final bool estaPesquisando;
  final SearchController? searchController;
  final Modelowordprodutos item;
  final ModeloCategoria? categoria;

  const CardProduto({
    super.key,
    this.searchController,
    required this.estaPesquisando,
    required this.item,
    required this.categoria,
  });

  @override
  State<CardProduto> createState() => _CardProdutoState();
}

class _CardProdutoState extends State<CardProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  // final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  @override
  Widget build(BuildContext context) {
    var item = widget.item;

    if (provedorCardapio.tamanhosPizza != null && item.tamanhosPizza!.where((element) => element.id == provedorCardapio.tamanhosPizza!.id).firstOrNull != null) {
      item.valorVenda = item.tamanhosPizza!.where((element) => element.id == provedorCardapio.tamanhosPizza!.id).first.valor;
    }

    return ListenableBuilder(
      listenable: provedorCardapio,
      builder: (context, snapshot) {
        return LayoutBuilder(builder: (context, constraints) {
          return Card(
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              key: widget.key,
              onTap: () async {
                final idComanda = provedorCardapio.idComanda;
                final idMesa = provedorCardapio.idMesa;

                var comanda = idComanda.isEmpty ? 0 : idComanda;
                var mesa = idMesa.isEmpty ? 0 : idMesa;

                if (provedorCardapio.tamanhosPizza != null) {
                  if (provedorCardapio.saboresPizzaSelecionados.where((element) => element.id == item.id).isNotEmpty) {
                    provedorCardapio.saboresPizzaSelecionados.removeWhere((element) => element.id == item.id);
                    var listaSaboresPizza = [...provedorCardapio.saboresPizzaSelecionados.where((element) => element.id != item.id)];
                    provedorCardapio.saboresPizzaSelecionados = listaSaboresPizza;
                  } else {
                    if (provedorCardapio.saboresPizzaSelecionados.length < int.parse(provedorCardapio.tamanhosPizza!.saboreslimite)) {
                      var listaSaboresPizza = [...provedorCardapio.saboresPizzaSelecionados, item];
                      provedorCardapio.saboresPizzaSelecionados = listaSaboresPizza;
                    }
                  }

                  return;
                }

                if (widget.categoria != null && widget.categoria!.tamanhosPizza!.isNotEmpty && provedorCardapio.tamanhosPizza == null) {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Selecione um Tamanho'),
                    backgroundColor: Colors.red,
                  ));
                  return;
                }

                if (item.habilTipo == 'Pacote' || item.habilTipo == 'kit') {
                  if (widget.estaPesquisando) {
                    widget.searchController!.closeView(item.nome);
                  }

                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) {
                      return PaginaProduto(produto: item);
                    },
                  ));

                  return;
                }

                String valor = item.valorVenda;

                if (double.parse(valor) == 0) {
                  bool bloquear = true;
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    showDragHandle: false,
                    builder: (context) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: ModalAdicionarValor(
                          aoSalvar: (novoValor) {
                            valor = novoValor;
                            bloquear = false;
                          },
                        ),
                      );
                    },
                  );
                  if (bloquear) return;
                }

                if (!context.mounted) return;

                await carrinhoProvedor
                    .inserir(
                  Modelowordprodutos(
                    id: item.id,
                    nome: item.nome,
                    codigo: item.codigo,
                    estoque: item.estoque,
                    tamanho: item.tamanho,
                    foto: item.foto,
                    ativo: item.ativo,
                    descricao: item.descricao,
                    valorVenda: valor,
                    categoria: item.categoria,
                    nomeCategoria: item.nomeCategoria,
                    habilTipo: item.habilTipo,
                    ingredientes: item.ingredientes,
                    ativarCustoDeProducao: item.ativarCustoDeProducao,
                    ativarEdQtd: item.ativarEdQtd,
                    ativoLoja: item.ativoLoja,
                    dataLancado: item.dataLancado,
                    destinoDeImpressao: item.destinoDeImpressao,
                    habilItensRetirada: item.habilItensRetirada,
                    novo: item.novo,
                    observacao: item.observacao,
                    opcoesPacotes: item.opcoesPacotes,
                    quantidadePessoa: item.quantidadePessoa,
                    valorRestoDivisao: item.valorRestoDivisao,
                    valorTotalVendas: item.valorTotalVendas,
                    tamanhoLista: item.tamanhoLista,
                    quantidade: 1,
                  ),
                  provedorCardapio.tipo.nome,
                  mesa,
                  comanda,
                  item.valorVenda,
                  '',
                  item.id,
                  item.nome,
                  item.quantidade,
                  '',
                )
                    .then((sucesso) {
                  if (sucesso) {
                    // provedorCardapio.resetarTudo();
                    return;
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Ocorreu um erro'),
                      showCloseIcon: true,
                    ));
                  }
                }).whenComplete(() {});
              },
              onLongPress: () {
                if (widget.estaPesquisando) {
                  widget.searchController!.closeView(item.nome);
                }

                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) {
                    return PaginaProduto(produto: item);
                  },
                ));
              },
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  if (item.descontoProduto != null) ...[
                    Positioned(
                      top: 17,
                      left: -37,
                      child: SizedBox(
                        width: 120,
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.deepOrange,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 0,
                                  blurRadius: 7,
                                  offset: const Offset(0, 3), // changes position of shadow
                                ),
                              ],
                            ),
                            child: const Text('Promoção', style: TextStyle(fontSize: 10, color: Colors.white), textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  ],
                  if (item.opcoesPacotes != null && item.opcoesPacotes!.where((element) => element.id == 1).isNotEmpty) ...[
                    Positioned(
                      top: 17,
                      left: -37,
                      child: SizedBox(
                        width: 120,
                        child: Transform.rotate(
                          angle: -math.pi / 4,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.withOpacity(0.5),
                                  spreadRadius: 0,
                                  blurRadius: 7,
                                  offset: const Offset(0, 3), // changes position of shadow
                                ),
                              ],
                            ),
                            child: const Text('Cortesia', style: TextStyle(fontSize: 10, color: Colors.white), textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Row(
                    children: [
                      item.foto.isEmpty
                          ? Image.asset(Assets.produtoAsset, width: 100, height: 100)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: CachedNetworkImage(
                                width: 100,
                                height: 100,
                                fit: BoxFit.contain,
                                fadeOutDuration: const Duration(milliseconds: 100),
                                placeholder: (context, url) => const SizedBox(
                                  height: 50.0,
                                  width: 50.0,
                                  child: Center(child: CircularProgressIndicator()),
                                ),
                                errorWidget: (context, url, error) => const Icon(Icons.error),
                                imageUrl: item.foto,
                              ),
                            ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Align(
                              alignment: Alignment.topLeft,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width / 1.6,
                                child: Text(
                                  "${item.nome} ${item.tamanho}",
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width / 1.6,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 5),
                                  child: Text(
                                    // item.descricao.isEmpty ? 'Sem descrição' : item.descricao,
                                    'Código: ${item.codigo}',
                                    overflow: TextOverflow.fade,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      color: Color.fromARGB(255, 111, 111, 111),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (widget.categoria != null && widget.categoria!.tamanhosPizza!.isNotEmpty) ...[
                              if (provedorCardapio.tamanhosPizza == null) ...[
                                SizedBox(
                                  width: MediaQuery.of(context).size.width / 1.5,
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      "A partir de ${double.parse(item.tamanhosPizza?.first.valor ?? '0').obterReal()}",
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17),
                                    ),
                                  ),
                                ),
                              ] else if (item.tamanhosPizza!.where((element) => element.id == provedorCardapio.tamanhosPizza!.id).firstOrNull != null) ...[
                                SizedBox(
                                  width: MediaQuery.of(context).size.width / 1.5,
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      double.parse(item.tamanhosPizza!.where((element) => element.id == provedorCardapio.tamanhosPizza!.id).first.valor).obterReal(),
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17),
                                    ),
                                  ),
                                ),
                              ],
                            ] else if (item.descontoProduto == null) ...[
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 1.5,
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    double.parse(item.valorVenda).obterReal(),
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17),
                                  ),
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: constraints.maxWidth / 1.5,
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      SizedBox(
                                        height: 12,
                                        child: Text(
                                          (double.parse(item.valorVenda) + double.parse(item.descontoProduto!.valorretirado)).obterReal(),
                                          style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough),
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 15,
                                        child: Text(' por ', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                      ),
                                      SizedBox(
                                        height: 21,
                                        child: Text(
                                          double.parse(item.valorVenda).obterReal(),
                                          style: const TextStyle(fontSize: 14, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      SizedBox(
                                        height: 12,
                                        child: Align(
                                          alignment: Alignment.topCenter,
                                          child: Container(
                                            height: 10,
                                            decoration: BoxDecoration(
                                              color: Colors.deepOrange,
                                              borderRadius: BorderRadius.circular(30),
                                            ),
                                            child: Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 5),
                                              child: Text(
                                                '-${item.descontoProduto!.tipodedesconto == '1' ? "${double.parse(item.descontoProduto!.valordedesconto).toInt()}%" : double.parse(item.descontoProduto!.valordedesconto).obterReal()}',
                                                // '-10%',
                                                style: const TextStyle(fontSize: 7, color: Colors.white),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (provedorCardapio.saboresPizzaSelecionados.where((element) => element.id == item.id).isNotEmpty) ...[
                    Positioned(
                      right: 10,
                      top: 10,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(2.0),
                          child: Icon(Icons.check, color: Color.fromRGBO(255, 255, 255, 1)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
