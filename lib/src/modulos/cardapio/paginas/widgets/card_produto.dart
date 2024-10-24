import 'dart:math' as math;

import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_adicionar_valor.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_produto.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardProduto extends StatefulWidget {
  final bool estaPesquisando;
  final SearchController? searchController;
  final ModeloProduto item;
  final TipoCardapio tipo;
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;

  const CardProduto({
    super.key,
    this.searchController,
    required this.estaPesquisando,
    required this.item,
    required this.tipo,
    required this.idComanda,
    required this.idComandaPedido,
    required this.idMesa,
  });

  @override
  State<CardProduto> createState() => _CardProdutoState();
}

class _CardProdutoState extends State<CardProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: provedorCardapio,
      builder: (context, snapshot) {
        print(provedorCardapio.tamanhosPizza);
        return LayoutBuilder(builder: (context, constraints) {
          return Card(
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              key: widget.key,
              onTap: () async {
                final idComanda = widget.idComanda;
                final idMesa = widget.idMesa;

                var comanda = idComanda.isEmpty ? 0 : idComanda;
                var mesa = idMesa.isEmpty ? 0 : idMesa;

                if (provedorCardapio.tamanhosPizza != null) {
                  if (provedorCardapio.saboresPizzaSelecionados.where((element) => element.id == widget.item.id).isNotEmpty) {
                    provedorCardapio.saboresPizzaSelecionados.removeWhere((element) => element.id == widget.item.id);
                    var listaSaboresPizza = [...provedorCardapio.saboresPizzaSelecionados.where((element) => element.id != widget.item.id)];
                    provedorCardapio.saboresPizzaSelecionados = listaSaboresPizza;
                  } else {
                    if (provedorCardapio.saboresPizzaSelecionados.length < int.parse(provedorCardapio.tamanhosPizza!.saboreslimite)) {
                      var listaSaboresPizza = [...provedorCardapio.saboresPizzaSelecionados, widget.item];
                      provedorCardapio.saboresPizzaSelecionados = listaSaboresPizza;
                    }
                  }

                  return;
                }
                if (widget.item.habilTipo == 'Pacote' || widget.item.habilTipo == 'kit') {
                  if (widget.estaPesquisando) {
                    widget.searchController!.closeView(widget.item.nome);
                  }

                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) {
                      return PaginaProduto(idComanda: widget.idComanda, idComandaPedido: widget.idComandaPedido, idMesa: widget.idMesa, tipo: widget.tipo, produto: widget.item.id);
                    },
                  ));

                  return;
                }

                String valor = widget.item.valorVenda;

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
                  ModeloProduto(
                    id: widget.item.id,
                    nome: widget.item.nome,
                    codigo: widget.item.codigo,
                    estoque: widget.item.estoque,
                    tamanho: widget.item.tamanho,
                    foto: widget.item.foto,
                    ativo: widget.item.ativo,
                    descricao: widget.item.descricao,
                    valorVenda: valor,
                    categoria: widget.item.categoria,
                    nomeCategoria: widget.item.nomeCategoria,
                    habilTipo: widget.item.habilTipo,
                    // cortesias: widget.item.cortesias,
                    // kits: widget.item.kits,
                    // adicionais: widget.item.adicionais,
                    // acompanhamentos: widget.item.acompanhamentos,
                    // tamanhos: widget.item.tamanhos,
                    // itensRetiradas: widget.item.itensRetiradas,
                    ingredientes: widget.item.ingredientes,
                    ativarCustoDeProducao: widget.item.ativarCustoDeProducao,
                    ativarEdQtd: widget.item.ativarEdQtd,
                    ativoLoja: widget.item.ativoLoja,
                    dataLancado: widget.item.dataLancado,
                    destinoDeImpressao: widget.item.destinoDeImpressao,
                    habilItensRetirada: widget.item.habilItensRetirada,
                    novo: widget.item.novo,
                    observacao: widget.item.observacao,
                    opcoesPacotes: widget.item.opcoesPacotes,
                    quantidadePessoa: widget.item.quantidadePessoa,
                    valorRestoDivisao: widget.item.valorRestoDivisao,
                    valorTotalVendas: widget.item.valorTotalVendas,
                    tamanhoLista: widget.item.tamanhoLista,
                    quantidade: 1,
                  ),
                  widget.tipo.nome,
                  mesa,
                  comanda,
                  widget.idComandaPedido,
                  widget.item.valorVenda,
                  '',
                  widget.item.id,
                  widget.item.nome,
                  widget.item.quantidade,
                  '',
                )
                    .then((sucesso) {
                  if (sucesso) {
                    _provedorProduto.resetarTudo();
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
                  widget.searchController!.closeView(widget.item.nome);
                }

                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) {
                    return PaginaProduto(idComanda: widget.idComanda, idComandaPedido: widget.idComandaPedido, idMesa: widget.idMesa, tipo: widget.tipo, produto: widget.item.id);
                  },
                ));
              },
              borderRadius: BorderRadius.circular(5),
              child: Stack(
                children: [
                  if (widget.item.descontoProduto != null) ...[
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
                  if (widget.item.opcoesPacotes != null && widget.item.opcoesPacotes!.where((element) => element.id == 6).isNotEmpty) ...[
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
                      widget.item.foto.isEmpty
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
                                imageUrl: widget.item.foto,
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
                                  "${widget.item.nome} ${widget.item.tamanho}",
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
                                    // widget.item.descricao.isEmpty ? 'Sem descrição' : widget.item.descricao,
                                    'Código: ${widget.item.codigo}',
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
                            if (widget.item.descontoProduto == null) ...[
                              SizedBox(
                                width: MediaQuery.of(context).size.width / 1.5,
                                child: Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    double.parse(widget.item.valorVenda).obterReal(),
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
                                          (double.parse(widget.item.valorVenda) + double.parse(widget.item.descontoProduto!.valorretirado)).obterReal(),
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
                                          double.parse(widget.item.valorVenda).obterReal(),
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
                                                '-${widget.item.descontoProduto!.tipodedesconto == '1' ? "${double.parse(widget.item.descontoProduto!.valordedesconto).toInt()}%" : double.parse(widget.item.descontoProduto!.valordedesconto).obterReal()}',
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
                ],
              ),
            ),
          );
        });
      },
    );
  }
}
