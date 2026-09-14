import 'package:app/src/essencial/widgets/linha_valor.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/modelos/valores_pizza.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_pedido_kit.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_editar_observacao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/conferencia_produto_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/titulo_opcoes_carrinho.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:flutter_modular/flutter_modular.dart';

class CardCarrinho extends StatefulWidget {
  final Modelowordprodutos item;
  final String idComanda;

  final int index;
  final String idMesa;
  final dynamic value;
  final Future<bool> Function(bool increase) setarQuantidade;
  final VoidCallback aoExcluirItem;

  const CardCarrinho({
    super.key,
    required this.item,
    required this.index,
    required this.idComanda,
    required this.idMesa,
    required this.value,
    required this.setarQuantidade,
    required this.aoExcluirItem,
  });

  @override
  State<CardCarrinho> createState() => _CardCarrinhoState();
}

class _CardCarrinhoState extends State<CardCarrinho>
    with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Tween<double> _sizeTween;
  bool _isExpanded = false;
  bool _processandoAcao = false;

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

  void _mostrarErro() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ocorreu um erro'),
        showCloseIcon: true,
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _confirmarAlteracaoQuantidade(bool aumentar) async {
    if (_processandoAcao) return;

    final quantidadeAtual = (widget.item.quantidade ?? 1).toInt();
    final novaQuantidade = quantidadeAtual + (aumentar ? 1 : -1);
    final confirmado = await _mostrarConfirmacaoItem(
      tipo: aumentar
          ? _TipoConfirmacaoCarrinho.aumentar
          : _TipoConfirmacaoCarrinho.diminuir,
      titulo:
          aumentar ? 'Adicionar mais uma unidade?' : 'Diminuir uma unidade?',
      mensagem: aumentar
          ? 'Confirme para aumentar a quantidade deste item no carrinho.'
          : 'A quantidade será reduzida, mas o item continuará no carrinho.',
      textoAcao: aumentar ? 'Adicionar' : 'Diminuir',
      quantidadeAtual: quantidadeAtual,
      novaQuantidade: novaQuantidade,
    );

    if (!mounted || !confirmado) return;

    setState(() => _processandoAcao = true);
    try {
      final sucesso = await widget.setarQuantidade(aumentar);
      if (!sucesso) _mostrarErro();
    } catch (_) {
      _mostrarErro();
    } finally {
      if (mounted) {
        setState(() => _processandoAcao = false);
      }
    }
  }

  Future<void> _confirmarExclusaoItem() async {
    if (_processandoAcao) return;

    final confirmado = await _mostrarConfirmacaoItem(
      tipo: _TipoConfirmacaoCarrinho.excluir,
      titulo: 'Excluir item?',
      mensagem: 'Essa ação remove o produto do carrinho.',
      textoAcao: 'Excluir',
    );

    if (!mounted || !confirmado) return;

    setState(() => _processandoAcao = true);
    try {
      final sucesso = await carrinhoProvedor.excluirItemCarrinho(
          widget.item.id, widget.index);

      if (!sucesso) {
        _mostrarErro();
        return;
      }

      await carrinhoProvedor.listarComandasPedidos();
      widget.aoExcluirItem();
    } catch (_) {
      _mostrarErro();
    } finally {
      if (mounted) {
        setState(() => _processandoAcao = false);
      }
    }
  }

  Future<bool> _mostrarConfirmacaoItem({
    required _TipoConfirmacaoCarrinho tipo,
    required String titulo,
    required String mensagem,
    required String textoAcao,
    int? quantidadeAtual,
    int? novaQuantidade,
  }) async {
    final cs = Theme.of(context).colorScheme;
    final tema = _ConfirmacaoTema.de(tipo, cs);

    return await showDialog<bool>(
          context: context,
          builder: (contextDialogo) {
            return Dialog(
              key: const ValueKey('confirmacao_carrinho_dialogo'),
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
              backgroundColor: cs.surfaceContainerHigh,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: tema.fundoIcone,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(tema.icone,
                                color: tema.corIcone, size: 23),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              titulo,
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        mensagem,
                        style:
                            TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.55)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shopping_bag_outlined,
                                size: 20, color: cs.onSurfaceVariant),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _nomeExibicaoItem(widget.item),
                                style: const TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (quantidadeAtual != null &&
                          novaQuantidade != null) ...[
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                                child: _QuantidadeConfirmacao(
                                    rotulo: 'Atual', valor: quantidadeAtual)),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 18, color: cs.onSurfaceVariant),
                            ),
                            Expanded(
                                child: _QuantidadeConfirmacao(
                                    rotulo: 'Nova', valor: novaQuantidade)),
                          ],
                        ),
                      ],
                      const SizedBox(height: 22),
                      Align(
                        key: const ValueKey('confirmacao_carrinho_acoes'),
                        alignment: Alignment.centerRight,
                        child: Wrap(
                          alignment: WrapAlignment.end,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            TextButton(
                              key: const ValueKey(
                                  'confirmacao_carrinho_cancelar'),
                              onPressed: () =>
                                  Navigator.pop(contextDialogo, false),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('Cancelar'),
                            ),
                            FilledButton.icon(
                              key: const ValueKey('confirmacao_carrinho_acao'),
                              onPressed: () =>
                                  Navigator.pop(contextDialogo, true),
                              icon: Icon(tema.iconeAcao, size: 18),
                              label: Text(textoAcao),
                              style: FilledButton.styleFrom(
                                backgroundColor: tema.corAcao,
                                foregroundColor: tema.corTextoAcao,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ) ??
        false;
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
                padding: const EdgeInsets.all(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinhaValor(
                      descricao: Text(nomeExibicao,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      valor: Text(
                        (double.parse(item.valorVenda) *
                                item.quantidade!.toInt())
                            .obterReal(),
                        textAlign: TextAlign.end,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: VisualAtendimento.verde(context)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                            child: Text('Código: ${item.codigo}',
                                style: const TextStyle(fontSize: 13))),
                        if (item.tamanho != '' && item.tamanho != '0')
                          Flexible(
                              child: Text(item.tamanho,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(fontSize: 13))),
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
                        TextButton.icon(
                          icon: const Icon(Icons.edit_note_rounded, size: 20),
                          onPressed: () {
                            showModalBottomSheet(
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              context: context,
                              builder: (context) => ModalEditarObservacao(
                                index: widget.index,
                                idProduto: item.id,
                                observacao: item.observacao ?? '',
                              ),
                            );
                          },
                          label: const Text('Observação'),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: item.quantidade! <= 1
                                  ? 'Excluir item'
                                  : 'Diminuir quantidade',
                              icon: _processandoAcao
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : Icon(item.quantidade! <= 1
                                      ? Icons.delete_outline_outlined
                                      : Icons.remove_circle_outline_outlined),
                              onPressed: _processandoAcao
                                  ? null
                                  : () {
                                      if (item.quantidade! <= 1) {
                                        _confirmarExclusaoItem();
                                      } else {
                                        _confirmarAlteracaoQuantidade(false);
                                      }
                                    },
                            ),
                            ConstrainedBox(
                              constraints: const BoxConstraints(minWidth: 30),
                              child: Text(item.quantidade!.toStringAsFixed(0),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 16)),
                            ),
                            IconButton(
                              tooltip: 'Aumentar quantidade',
                              icon:
                                  const Icon(Icons.add_circle_outline_outlined),
                              onPressed: _processandoAcao
                                  ? null
                                  : () => _confirmarAlteracaoQuantidade(true),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (item.observacao?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 6),
                      Text(item.observacao!,
                          style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          AcoesProdutoCarrinho(
            item: item,
            index: widget.index,
            aoConferir: (conferido) => carrinhoProvedor.definirConferencia(
                item, widget.index, conferido),
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
                                _descricaoOpcaoCarrinho(
                                    e.id, dado, e.dados!.length),
                                style: const TextStyle(fontSize: 15),
                              ),
                              valor: Text(
                                (double.parse(dado.valor ?? '0') *
                                        (dado.quantidade ?? 1))
                                    .obterReal(),
                                style: TextStyle(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize: 16),
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
                if ((item.opcoesPacotesListaFinal ?? []).isNotEmpty)
                  TotalOpcoesCarrinho(item: item),
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

  String _descricaoOpcaoCarrinho(
      int idOpcao, ModeloDadosOpcoesPacotes dado, int totalDados) {
    if (idOpcao == 10) {
      final proporcao = dado.quantimaximaselecao?.trim();
      final prefixo = proporcao == null || proporcao.isEmpty ? null : proporcao;
      return _nomeSaborPizza(dado, prefixo);
    }

    if (idOpcao == 6) {
      return ValoresPizza.nomeBordaCarrinho(dado, totalDados);
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

enum _TipoConfirmacaoCarrinho { aumentar, diminuir, excluir }

class _ConfirmacaoTema {
  final IconData icone;
  final IconData iconeAcao;
  final Color fundoIcone;
  final Color corIcone;
  final Color corAcao;
  final Color corTextoAcao;

  const _ConfirmacaoTema({
    required this.icone,
    required this.iconeAcao,
    required this.fundoIcone,
    required this.corIcone,
    required this.corAcao,
    required this.corTextoAcao,
  });

  factory _ConfirmacaoTema.de(_TipoConfirmacaoCarrinho tipo, ColorScheme cs) {
    switch (tipo) {
      case _TipoConfirmacaoCarrinho.aumentar:
        return _ConfirmacaoTema(
          icone: Icons.add_shopping_cart_rounded,
          iconeAcao: Icons.add_circle_outline_rounded,
          fundoIcone: cs.primaryContainer,
          corIcone: cs.onPrimaryContainer,
          corAcao: cs.primary,
          corTextoAcao: cs.onPrimary,
        );
      case _TipoConfirmacaoCarrinho.diminuir:
        return _ConfirmacaoTema(
          icone: Icons.remove_shopping_cart_outlined,
          iconeAcao: Icons.remove_circle_outline_rounded,
          fundoIcone: cs.secondaryContainer,
          corIcone: cs.onSecondaryContainer,
          corAcao: cs.secondary,
          corTextoAcao: cs.onSecondary,
        );
      case _TipoConfirmacaoCarrinho.excluir:
        return _ConfirmacaoTema(
          icone: Icons.delete_outline_rounded,
          iconeAcao: Icons.delete_outline_rounded,
          fundoIcone: cs.errorContainer,
          corIcone: cs.onErrorContainer,
          corAcao: cs.error,
          corTextoAcao: cs.onError,
        );
    }
  }
}

class _QuantidadeConfirmacao extends StatelessWidget {
  final String rotulo;
  final int valor;

  const _QuantidadeConfirmacao({required this.rotulo, required this.valor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      key: ValueKey('quantidade_confirmacao_$rotulo'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            rotulo,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 3),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$valor',
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
