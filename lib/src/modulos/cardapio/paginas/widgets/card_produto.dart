import 'dart:math' as math;

import 'package:app/src/essencial/utils/normalizar_busca.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/essencial/utils/url_imagem.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_adicionar_valor.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/modal_quantidade_gramas.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/uteis/produto_vendido_por_peso.dart';
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
  final bool finalizar;
  final bool favorito;
  final VoidCallback? aoAlternarFavorito;
  final ProvedorCardapio? cardapioEdicao;
  final ValueChanged<Modelowordprodutos>? aoSelecionarSabor;
  final bool modeloRecorrente;

  const CardProduto({
    super.key,
    this.searchController,
    required this.estaPesquisando,
    required this.item,
    required this.categoria,
    required this.finalizar,
    this.favorito = false,
    this.aoAlternarFavorito,
    this.cardapioEdicao,
    this.aoSelecionarSabor,
    this.modeloRecorrente = false,
  }) : assert((cardapioEdicao == null) == (aoSelecionarSabor == null));

  @override
  State<CardProduto> createState() => _CardProdutoState();
}

class _CardProdutoState extends State<CardProduto> {
  late final ProvedorCarrinho carrinhoProvedor =
      Modular.get<ProvedorCarrinho>();
  late final ProvedorCardapio provedorCardapio =
      widget.cardapioEdicao ?? Modular.get<ProvedorCardapio>();
  late final Listenable _alteracoes = widget.cardapioEdicao != null
      ? provedorCardapio
      : Listenable.merge([provedorCardapio, carrinhoProvedor]);
  String? _baseHostImagens;

  @override
  void initState() {
    super.initState();
    _carregarBaseHostImagens();
  }

  Future<void> _carregarBaseHostImagens() async {
    if (widget.item.foto.isEmpty) return;
    try {
      final baseHost = await UrlImagem.obterBaseHostImagens();
      if (!mounted) return;
      setState(() => _baseHostImagens = baseHost);
    } catch (_) {
      // A imagem nao bloqueia o atendimento.
    }
  }

  bool _idCardapioValido(String? id) {
    final texto = id?.trim().toLowerCase() ?? '';
    return texto.isNotEmpty && texto != '0' && texto != 'null';
  }

  bool _temCategoriaCardapio(Modelowordprodutos item) {
    if (_idCardapioValido(item.idCategoriaCardapio)) return true;
    return (item.opcoesPacotes ?? const []).any((grupo) =>
        grupo.tipo == 8 ||
        (grupo.dados ?? const []).any(
          (dado) => _idCardapioValido(dado.idCategoriaCardapio),
        ));
  }

  bool _produtoPersonalizavel(Modelowordprodutos item) {
    final habilTipo = item.habilTipo.trim().toLowerCase();
    return habilTipo == 'pacote' ||
        habilTipo == 'kit' ||
        _temCategoriaCardapio(item);
  }

  bool _montagemCardapioCompleta(Modelowordprodutos item) {
    if (widget.modeloRecorrente) return false;

    // A listagem atual da API ja pode trazer toda a montagem do dia. Nesse
    // caso abrir outra consulta deixa um atraso perceptivel sem acrescentar
    // informacao. So reutilize quando o grupo de Cardapio estiver claramente
    // identificado e possuir ingredientes; adicionais comuns nunca entram
    // neste atalho.
    return (item.opcoesPacotes ?? const []).any((grupo) {
      final dados = grupo.dados ?? const [];
      final grupoCardapio = grupo.tipo == 8 ||
          grupo.id == 12 ||
          dados.any(
            (dado) => _idCardapioValido(dado.idCategoriaCardapio),
          );
      return grupoCardapio && dados.isNotEmpty;
    });
  }

  String _preco(bool pizza) {
    final item = widget.item;
    final selecionado =
        pizza ? provedorCardapio.tamanhoPizzaDoProduto(item) : null;
    if (selecionado != null) {
      return (double.tryParse(selecionado.valor) ?? 0).obterReal();
    }
    if (!pizza && item.descontoProduto != null) {
      return (double.tryParse(item.valorVenda) ?? 0).obterReal();
    }
    final valores = pizza
        ? item.tamanhosPizza
                ?.map((t) => double.tryParse(t.valor))
                .whereType<double>()
                .toList() ??
            <double>[]
        : item.opcoesPacotes
                ?.where((o) => o.id == 4)
                .firstOrNull
                ?.dados
                ?.map((t) => double.tryParse(t.valor ?? ''))
                .whereType<double>()
                .toList() ??
            <double>[];
    final minimo = valores.isEmpty
        ? double.tryParse(item.valorVenda) ?? 0
        : valores.reduce(math.min);
    final maximo = valores.isEmpty ? minimo : valores.reduce(math.max);
    if (pizza) return 'A partir de ${minimo.obterReal()}';
    return minimo == maximo
        ? minimo.obterReal()
        : '${minimo.obterReal()} a ${maximo.obterReal()}';
  }

  @override
  Widget build(BuildContext context) {
    var item = widget.item;

    return ListenableBuilder(
      listenable: _alteracoes,
      builder: (context, snapshot) {
        final categoriaProduto = provedorCardapio.categorias
                .where((categoria) => categoria.id == item.categoria)
                .firstOrNull ??
            (widget.categoria?.id == item.categoria ? widget.categoria : null);
        final temTamanhosPizza = (item.tamanhosPizza?.isNotEmpty ?? false) ||
            (categoriaProduto?.tamanhosPizza?.isNotEmpty ?? false);
        final tamanhoSelecionado = provedorCardapio.tamanhoPizzaDoProduto(item);
        final selecionado = provedorCardapio.saboresPizzaSelecionados
            .any((sabor) => sabor.id == item.id);
        final quantidadeNoCarrinho = temTamanhosPizza
            ? 0.0
            : carrinhoProvedor.quantidadeDoProduto(item.id);
        final marcado = selecionado || quantidadeNoCarrinho > 0;
        final vendidoPorPeso = produtoVendidoPorPeso(item);
        final quantidadeTexto = vendidoPorPeso
            ? '${(quantidadeNoCarrinho * 1000).round()} g'
            : quantidadeNoCarrinho
                .toStringAsFixed(quantidadeNoCarrinho % 1 == 0 ? 0 : 2)
                .replaceAll('.', ',');
        final cs = Theme.of(context).colorScheme;

        final indisponivel = normalizarBusca(item.ativo) == 'nao';
        final personalizavel = _produtoPersonalizavel(item);
        Future<void> selecionar() async {
          if (indisponivel) return;

          FocusManager.instance.primaryFocus?.unfocus();
          if (widget.aoSelecionarSabor != null) {
            widget.aoSelecionarSabor!(item);
            return;
          }
          final idComanda = provedorCardapio.idComanda;
          final idMesa = provedorCardapio.idMesa;

          var comanda = idComanda.isEmpty ? 0 : idComanda;
          var mesa = idMesa.isEmpty ? 0 : idMesa;

          if (temTamanhosPizza && tamanhoSelecionado != null) {
            final estavaSelecionado = provedorCardapio.saboresPizzaSelecionados
                .any((sabor) => sabor.id == item.id);
            provedorCardapio.selecionarSaborPizza(item);
            final ficouSelecionado = provedorCardapio.saboresPizzaSelecionados
                .any((sabor) => sabor.id == item.id);
            if (estavaSelecionado != ficouSelecionado) {
              FeedbackUsuario.selecaoAlterada();
            }
            return;
          }

          if (temTamanhosPizza) {
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(provedorCardapio.tamanhosPizza == null
                  ? 'Selecione um Tamanho'
                  : 'Selecione um tamanho disponível para este sabor.'),
              backgroundColor: Colors.red,
            ));
            return;
          }

          if (personalizavel) {
            if (widget.estaPesquisando) {
              widget.searchController!.closeView(item.nome);
            }

            Navigator.of(context).push(MaterialPageRoute(
              builder: (context) {
                return PaginaProduto(
                  produto: item,
                  modeloRecorrente: widget.modeloRecorrente,
                  detalhesJaCarregados: _montagemCardapioCompleta(item),
                );
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

          var quantidade = 1.0;
          if (vendidoPorPeso) {
            if (!context.mounted) return;
            final peso = await showModalBottomSheet<QuantidadeProdutoPorPeso>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              showDragHandle: false,
              builder: (_) => ModalQuantidadeGramas(
                nomeProduto: item.nome,
                precoPorQuilo: double.tryParse(valor) ?? 0,
              ),
            );
            if (peso == null) return;
            quantidade = peso.quilos;
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
              idCategoriaCardapio: item.idCategoriaCardapio,
              novo: item.novo,
              observacao: item.observacao,
              opcoesPacotes: item.opcoesPacotes,
              quantidadePessoa: item.quantidadePessoa,
              valorRestoDivisao: item.valorRestoDivisao,
              valorTotalVendas: item.valorTotalVendas,
              tamanhoLista: item.tamanhoLista,
              quantidade: quantidade,
            ),
            provedorCardapio.tipo.nome,
            mesa,
            comanda,
            valor,
            '',
            item.id,
            item.nome,
            quantidade,
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
        }

        void abrirDetalhes() {
          FocusManager.instance.primaryFocus?.unfocus();
          if (widget.estaPesquisando) {
            widget.searchController!.closeView(item.nome);
          }
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => PaginaProduto(
              produto: item,
              modeloRecorrente: widget.modeloRecorrente,
              detalhesJaCarregados: _montagemCardapioCompleta(item),
            ),
          ));
        }

        final precoCor = Theme.of(context).brightness == Brightness.dark
            ? Colors.green.shade300
            : Colors.green.shade800;
        final temFoto = item.foto.trim().isNotEmpty;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          elevation: 0,
          color: marcado
              ? cs.secondaryContainer.withValues(alpha: 0.25)
              : cs.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: marcado ? cs.primary : cs.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: indisponivel ? null : selecionar,
            onLongPress:
                indisponivel || temTamanhosPizza ? null : abrirDetalhes,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (temFoto) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: _baseHostImagens == null
                            ? Icon(Icons.restaurant_outlined,
                                color: cs.onSurfaceVariant)
                            : CachedNetworkImage(
                                imageUrl: UrlImagem.montarUrlImagem(
                                    foto: item.foto,
                                    baseHost: _baseHostImagens!),
                                fit: BoxFit.contain,
                                memCacheWidth: (56 *
                                        MediaQuery.devicePixelRatioOf(context))
                                    .round(),
                                placeholder: (context, url) => Icon(
                                    Icons.restaurant_outlined,
                                    color: cs.onSurfaceVariant),
                                errorWidget: (context, url, erro) => Icon(
                                    Icons.restaurant_outlined,
                                    color: cs.onSurfaceVariant),
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${item.nome} ${item.tamanho}'.trim(),
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: indisponivel
                                    ? cs.onSurfaceVariant
                                    : cs.onSurface)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text('Código: ${item.codigo}',
                                style: TextStyle(
                                    fontSize: 12, color: cs.onSurfaceVariant)),
                            if (temTamanhosPizza || personalizavel)
                              Text(
                                  temTamanhosPizza ? 'Pizza' : 'Personalizável',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                            if (vendidoPorPeso)
                              Text('Por peso',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                            if (item.descontoProduto != null)
                              Text('Promoção',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: precoCor)),
                            if (item.opcoesPacotes?.any((o) => o.id == 1) ??
                                false)
                              Text('Cortesia',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (!indisponivel &&
                            !temTamanhosPizza &&
                            item.descontoProduto != null)
                          Text(
                              ((double.tryParse(item.valorVenda) ?? 0) +
                                      (double.tryParse(item.descontoProduto!
                                              .valorretirado) ??
                                          0))
                                  .obterReal(),
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  decoration: TextDecoration.lineThrough)),
                        if (indisponivel)
                          Text('Indisponível',
                              style: TextStyle(
                                  color: cs.error,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600))
                        else
                          Text(
                              vendidoPorPeso
                                  ? '${_preco(temTamanhosPizza)} / kg'
                                  : _preco(temTamanhosPizza),
                              style: TextStyle(
                                  color: precoCor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700)),
                        if (quantidadeNoCarrinho > 0)
                          DefaultTextStyle.merge(
                            key: ValueKey('quantidade_carrinho_${item.id}'),
                            style: TextStyle(
                                color: cs.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                            child: Wrap(spacing: 4, children: [
                              Text(quantidadeTexto),
                              const Text('no carrinho')
                            ]),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.aoAlternarFavorito != null)
                        IconButton(
                          key: ValueKey('favorito_${item.id}'),
                          tooltip: widget.favorito
                              ? 'Remover dos favoritos'
                              : 'Adicionar aos favoritos',
                          isSelected: widget.favorito,
                          selectedIcon: const Icon(Icons.star_rounded),
                          icon: const Icon(Icons.star_outline_rounded),
                          color: widget.favorito
                              ? cs.primary
                              : cs.onSurfaceVariant,
                          constraints: const BoxConstraints.tightFor(
                              width: 48, height: 48),
                          onPressed: widget.aoAlternarFavorito,
                        ),
                      IconButton(
                        key: ValueKey('adicionar_produto_${item.id}'),
                        tooltip: indisponivel
                            ? 'Produto indisponível'
                            : temTamanhosPizza
                                ? (selecionado
                                    ? 'Remover sabor'
                                    : 'Selecionar sabor')
                                : personalizavel
                                    ? 'Personalizar produto'
                                    : vendidoPorPeso
                                        ? 'Informar peso em gramas'
                                        : 'Adicionar ao carrinho',
                        constraints: const BoxConstraints.tightFor(
                            width: 48, height: 48),
                        color: selecionado ? precoCor : cs.primary,
                        onPressed: indisponivel ? null : selecionar,
                        icon: Icon(
                            temTamanhosPizza
                                ? (selecionado
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline)
                                : personalizavel
                                    ? Icons.tune_rounded
                                    : vendidoPorPeso
                                        ? Icons.scale_outlined
                                        : Icons.add_circle_outline,
                            semanticLabel: selecionado ? 'Selecionado' : null),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
