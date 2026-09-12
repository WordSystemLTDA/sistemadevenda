import 'package:app/src/essencial/widgets/linha_valor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/conferencia_produto_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/titulo_opcoes_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_pedido_kit.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_editar_observacao.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardCarrinhoItensRecorrentes extends StatefulWidget {
  final Modelowordprodutos item;
  final String idComanda;
  final String idComandaPedido;
  final int index;
  final String idMesa;
  final dynamic value;
  final Function(bool increase) setarQuantidade;

  const CardCarrinhoItensRecorrentes({
    super.key,
    required this.item,
    required this.index,
    required this.idComanda,
    required this.idComandaPedido,
    required this.idMesa,
    required this.value,
    required this.setarQuantidade,
  });

  @override
  State<CardCarrinhoItensRecorrentes> createState() =>
      _CardCarrinhoItensRecorrentesState();
}

class _CardCarrinhoItensRecorrentesState
    extends State<CardCarrinhoItensRecorrentes> with TickerProviderStateMixin {
  // final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorItensRecorrentes provedorItensRecorrentes =
      Modular.get<ProvedorItensRecorrentes>();

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Tween<double> _sizeTween;
  bool _isExpanded = false;

  @override
  void initState() {
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _sizeTween = Tween(begin: 0, end: 1);
    super.initState();
  }

  void _expandOnChanged() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.item;
    final nomeExibicao = _nomeExibicaoItem(item);

    return CardConferenciaCarrinho(
      conferido: item.conferidoNoCarrinho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 115),
            child: InkWell(
              onTap: _expandOnChanged,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinhaValor(
                      descricao: Text(
                        nomeExibicao,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      valor: Text(
                        (double.parse(item.valorVenda) *
                                item.quantidade!.toInt())
                            .obterReal(),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Código: ${item.codigo}',
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        if (item.tamanho != '' && item.tamanho != '0')
                          Flexible(
                            child: Text(
                              item.tamanho,
                              textAlign: TextAlign.end,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        if ((item.opcoesPacotesListaFinal ?? []).isNotEmpty)
                          IconButton(
                            tooltip: _isExpanded
                                ? 'Ocultar detalhes'
                                : 'Mostrar detalhes',
                            onPressed: _expandOnChanged,
                            icon: Icon(_isExpanded
                                ? Icons.keyboard_arrow_up_outlined
                                : Icons.keyboard_arrow_down_outlined),
                          ),
                      ],
                    ),
                    OverflowBar(
                      alignment: MainAxisAlignment.spaceBetween,
                      overflowAlignment: OverflowBarAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () {
                            showModalBottomSheet(
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              context: context,
                              builder: (context) {
                                return ModalEditarObservacao(
                                  itensRecorrentes: true,
                                  idProduto: item.id,
                                  index: widget.index,
                                  observacao: item.observacao ?? '',
                                );
                              },
                            );
                          },
                          child: const Text('Observação'),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: item.quantidade! <= 1
                                  ? 'Excluir item'
                                  : 'Diminuir quantidade',
                              icon: item.quantidade! <= 1
                                  ? const Icon(Icons.delete_outline_outlined)
                                  : const Icon(
                                      Icons.remove_circle_outline_outlined),
                              onPressed: () {
                                if (item.quantidade! <= 1) {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text('Exclusão de Item'),
                                        content: const SingleChildScrollView(
                                          child: ListBody(
                                            children: <Widget>[
                                              Text(
                                                  'Deseja realmente excluir esse item?'),
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
                                              await provedorItensRecorrentes
                                                  .excluirItemCarrinho(
                                                      widget.idComandaPedido,
                                                      widget.index);
                                              if (context.mounted) {
                                                provedorItensRecorrentes
                                                    .listarComandasPedidos(
                                                        widget.idComandaPedido);
                                                Navigator.pop(context);
                                              }
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  widget.setarQuantidade(false);
                                }
                              },
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 30),
                              child: Text(
                                item.quantidade!.toStringAsFixed(0),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Aumentar quantidade',
                              icon:
                                  const Icon(Icons.add_circle_outline_outlined),
                              onPressed: () {
                                widget.setarQuantidade(true);
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          AcoesProdutoCarrinho(
            item: item,
            index: widget.index,
            recorrentes: true,
            aoConferir: (conferido) => provedorItensRecorrentes
                .definirConferencia(item, widget.index, conferido),
          ),
          SizeTransition(
            sizeFactor: _sizeTween.animate(_animation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((item.opcoesPacotesListaFinal ?? []).isNotEmpty) ...[
                  const Divider(height: 1),
                ],
                ...(item.opcoesPacotesListaFinal ?? []).map((e) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (e.dados != null && e.dados!.isNotEmpty) ...[
                        TituloOpcoesCarrinho(item: item, grupo: e),
                        ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 10, top: 5, right: 10, bottom: 5),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: e.dados!.length,
                          itemBuilder: (context, index) {
                            final dado = e.dados![index];

                            return LinhaValor(
                              descricao: Text(
                                _descricaoOpcaoCarrinho(e.id, dado),
                                style: const TextStyle(fontSize: 15),
                              ),
                              valor: Text(
                                (double.parse(dado.valor ?? '0') *
                                        (dado.quantidade ?? 1))
                                    .obterReal(),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontSize: 16,
                                ),
                              ),
                            );
                          },
                        ),
                      ] else if (e.produtos != null &&
                          e.produtos!.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.only(left: 10, top: 10),
                          child: Text(e.titulo,
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 10, top: 5, right: 10, bottom: 5),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: e.produtos!.length,
                          itemBuilder: (context, index) {
                            final produto = e.produtos![index];

                            return CardPedidoKit(
                                item: produto, somarValores: false);
                          },
                        ),
                      ],
                    ],
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _nomeExibicaoItem(Modelowordprodutos item) {
    final saboresPizza = (item.opcoesPacotesListaFinal ?? [])
        .where((opcao) => opcao.id == 10)
        .firstOrNull
        ?.dados;

    if (saboresPizza == null || saboresPizza.isEmpty) {
      return item.nome;
    }

    final totalSabores = saboresPizza.length;
    return saboresPizza.map((sabor) {
      final proporcao = sabor.quantimaximaselecao?.trim();
      final prefixo = proporcao == null || proporcao.isEmpty
          ? '1/$totalSabores'
          : proporcao;
      return _nomeSaborPizza(sabor, prefixo);
    }).join('\n');
  }

  String _descricaoOpcaoCarrinho(int idOpcao, ModeloDadosOpcoesPacotes dado) {
    if (idOpcao == 10) {
      final proporcao = dado.quantimaximaselecao?.trim();
      final prefixo = proporcao == null || proporcao.isEmpty ? null : proporcao;
      return _nomeSaborPizza(dado, prefixo);
    }

    return '${dado.quantimaximaselecao != null ? '(${dado.quantimaximaselecao}) ' : dado.quantidade != null ? '${dado.quantidade}x ' : ''}${dado.nome}';
  }

  String _nomeSaborPizza(ModeloDadosOpcoesPacotes sabor, String? proporcao) {
    final nome = proporcao == null || proporcao.isEmpty
        ? sabor.nome
        : '($proporcao) ${sabor.nome}';
    final codigo = sabor.codigo?.trim() ?? '';

    if (sabor.imprimirCodigoProdutoPreparo != 'Sim' || codigo.isEmpty) {
      return nome;
    }

    final prefixo = '$codigo - ';
    return nome.startsWith(prefixo) ? nome : '$prefixo$nome';
  }
}
