import 'dart:math' as math;

import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/essencial/utils/url_imagem.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
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
  final Modelowordprodutos item;
  final ModeloCategoria? categoria;
  final bool finalizar;

  const CardProduto({
    super.key,
    this.searchController,
    required this.estaPesquisando,
    required this.item,
    required this.categoria,
    required this.finalizar,
  });

  @override
  State<CardProduto> createState() => _CardProdutoState();
}

class _CardProdutoState extends State<CardProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  String? _baseHostImagens;

  @override
  void initState() {
    super.initState();
    _carregarBaseHostImagens();
  }

  Future<void> _carregarBaseHostImagens() async {
    final baseHost = await UrlImagem.obterBaseHostImagens();
    if (!mounted) {
      return;
    }
    setState(() {
      _baseHostImagens = baseHost;
    });
  }

  Widget retornoValorVendaProduto() {
    var texto = '';

    // if (provedor.categorias.where((element) => int.parse(element.id) == provedor.categoriaSelecionada).firstOrNull != null &&
    //     provedor.categorias.where((element) => int.parse(element.id) == provedor.categoriaSelecionada).first.tamanhosPizza != null &&
    //     provedor.categorias.where((element) => int.parse(element.id) == provedor.categoriaSelecionada).first.tamanhosPizza!.isNotEmpty &&
    //     provedor.tamanhosPizza == null) {
    //   texto = 'A partir ';
    //   texto += (double.parse(itemProduto.valorVenda) * (widget.finalizar ? (itemProduto.quantidade ?? 1) : 1)).obterReal(2);
    // } else {
    if (widget.item.habilTipo == 'Pacote' && (widget.item.opcoesPacotesListaFinal != null && widget.item.opcoesPacotesListaFinal!.isNotEmpty)) {
      var dadosPacotes = widget.item.opcoesPacotesListaFinal!.where((element) => element.id == 4).firstOrNull;

      // se tiver tamanhos irá aparecer assim
      if (dadosPacotes != null && (dadosPacotes.dados != null && dadosPacotes.dados!.isNotEmpty)) {
        if ((dadosPacotes.dados!.first.valor == dadosPacotes.dados!.last.valor)) {
          texto += double.parse(dadosPacotes.dados!.first.valor ?? '0').obterReal();
        } else {
          texto += "${double.parse(dadosPacotes.dados!.first.valor ?? '0').obterReal()} à ${double.parse(dadosPacotes.dados!.last.valor ?? '0').obterReal()}";
        }
      } else {
        texto = (double.parse(widget.item.valorVenda) * (widget.finalizar ? (widget.item.quantidade ?? 1) : 1)).obterReal(2);
      }
    } else {
      texto = (double.parse(widget.item.valorVenda) * (widget.finalizar ? (widget.item.quantidade ?? 1) : 1)).obterReal(2);
    }
    // }

    // if (widget.item.id == '563') {
    //   print('VV --> ${widget.item.valorVenda}');
    // }

    return Text(
      texto,
      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 17),
    );
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.item;

    return ListenableBuilder(
      listenable: provedorCardapio,
      builder: (context, snapshot) {
        final categoriaProduto = provedorCardapio.categorias.where((categoria) => categoria.id == item.categoria).firstOrNull ??
            (widget.categoria?.id == item.categoria ? widget.categoria : null);
        final temTamanhosPizza = (item.tamanhosPizza?.isNotEmpty ?? false) || (categoriaProduto?.tamanhosPizza?.isNotEmpty ?? false);
        final tamanhoSelecionado = provedorCardapio.tamanhoPizzaDoProduto(item);
        final selecionado = provedorCardapio.saboresPizzaSelecionados.any((sabor) => sabor.id == item.id);
        final cs = Theme.of(context).colorScheme;

        return LayoutBuilder(builder: (context, constraints) {
          return Card(
            elevation: 0,
            color: selecionado ? cs.secondaryContainer.withValues(alpha: 0.3) : cs.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: BorderSide(color: selecionado ? cs.primary : cs.outlineVariant),
            ),
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              key: widget.key,
              onTap: () async {
                final idComanda = provedorCardapio.idComanda;
                final idMesa = provedorCardapio.idMesa;

                var comanda = idComanda.isEmpty ? 0 : idComanda;
                var mesa = idMesa.isEmpty ? 0 : idMesa;

                if (temTamanhosPizza && tamanhoSelecionado != null) {
                  provedorCardapio.selecionarSaborPizza(item);
                  return;
                }

                if (temTamanhosPizza && (provedorCardapio.tamanhosPizza != null || (widget.categoria?.tamanhosPizza?.isNotEmpty ?? false))) {
                  ScaffoldMessenger.of(context).removeCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(provedorCardapio.tamanhosPizza == null ? 'Selecione um Tamanho' : 'Selecione um tamanho disponível para este sabor.'),
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
                    imprimirCodigoProdutoPreparo: item.imprimirCodigoProdutoPreparo,
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
                                  color: Colors.grey.withValues(alpha: 0.5),
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
                                  color: Colors.grey.withValues(alpha: .5),
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
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      item.foto.isEmpty || _baseHostImagens == null
                          ? Image.asset(Assets.produtoAsset, width: 88, height: 88)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: CachedNetworkImage(
                                width: 88,
                                height: 88,
                                memCacheWidth: (88 * MediaQuery.devicePixelRatioOf(context)).round(),
                                memCacheHeight: (88 * MediaQuery.devicePixelRatioOf(context)).round(),
                                fit: BoxFit.contain,
                                fadeOutDuration: const Duration(milliseconds: 100),
                                placeholder: (context, url) => Image.asset(Assets.produtoAsset, fit: BoxFit.contain),
                                errorWidget: (context, url, error) => Image.asset(Assets.produtoAsset, fit: BoxFit.contain),
                                imageUrl: UrlImagem.montarUrlImagem(
                                  foto: item.foto,
                                  baseHost: _baseHostImagens!,
                                ),
                              ),
                            ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      "${item.nome} ${item.tamanho}".trim(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  if (selecionado) ...[
                                    const SizedBox(width: 6),
                                    const Icon(Icons.check_circle, color: Colors.green, size: 24, semanticLabel: 'Selecionado'),
                                  ],
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Text(
                                  'Código: ${item.codigo}',
                                  overflow: TextOverflow.fade,
                                  maxLines: 2,
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (temTamanhosPizza) ...[
                                if (tamanhoSelecionado == null) ...[
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      "A partir de ${double.parse(item.tamanhosPizza?.firstOrNull?.valor ?? item.valorVenda).obterReal()}",
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ] else ...[
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      double.parse(tamanhoSelecionado.valor).obterReal(),
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                  ),
                                ],
                              ] else if (item.descontoProduto == null) ...[
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Text(
                                    (_provedorProduto.retornarDadosPorID([4], false, '0').isEmpty &&
                                            _provedorProduto.retornarDadosPorID([4], false, '0').firstOrNull == null &&
                                            item.opcoesPacotes?.where((element) => element.id == 4).firstOrNull != null)
                                        ? "${double.parse(item.opcoesPacotes!.where((element) => element.id == 4).first.dados!.first.valor ?? '0').obterReal()} à ${double.parse(item.opcoesPacotes!.where((element) => element.id == 4).first.dados!.last.valor ?? '0').obterReal()}"
                                        : (double.tryParse(item.valorVenda) ?? 0).obterReal(),
                                    style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                              ] else ...[
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: Wrap(
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    alignment: WrapAlignment.end,
                                    spacing: 4,
                                    children: [
                                      Text(
                                        (double.parse(item.valorVenda) + double.parse(item.descontoProduto!.valorretirado)).obterReal(),
                                        style: const TextStyle(
                                            fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600, decoration: TextDecoration.lineThrough),
                                      ),
                                      const Text('por', style: TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600)),
                                      Text(
                                        double.parse(item.valorVenda).obterReal(),
                                        style: const TextStyle(fontSize: 14, color: Colors.deepOrange, fontWeight: FontWeight.bold),
                                      ),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.deepOrange,
                                          borderRadius: BorderRadius.circular(30),
                                        ),
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        child: Text(
                                          '-${item.descontoProduto!.tipodedesconto == '1' ? "${double.parse(item.descontoProduto!.valordedesconto).toInt()}%" : double.parse(item.descontoProduto!.valordedesconto).obterReal()}',
                                          style: const TextStyle(fontSize: 8, color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
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
