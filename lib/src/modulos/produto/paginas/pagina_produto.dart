import 'package:app/src/essencial/constantes/assets_constantes.dart';
import 'package:app/src/essencial/utils/url_imagem.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_opcoes_pacotes.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_kit.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/produto/paginas/widgets/card_opcoes_pacotes.dart';
import 'package:app/src/modulos/produto/provedores/provedor_produto.dart';
import 'package:app/src/modulos/produto/servicos/servico_produto.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaProduto extends StatefulWidget {
  final Modelowordprodutos produto;
  final double? valorVenda;
  final bool editar;
  final bool montagemPizza;
  final int? indexProduto;
  final Function(Modelowordprodutos produto)? inserirEmItensRecorrentes;

  const PaginaProduto({
    super.key,
    required this.produto,
    this.valorVenda,
    this.editar = false,
    this.montagemPizza = false,
    this.indexProduto,
    this.inserirEmItensRecorrentes,
  });

  @override
  State<PaginaProduto> createState() => _PaginaProdutoState();
}

class _PaginaProdutoState extends State<PaginaProduto> {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorProduto _provedorProduto = Modular.get<ProvedorProduto>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();

  Modelowordprodutos? itemProduto;
  bool carregando = false;
  TextEditingController obsController = TextEditingController();
  String _baseHostImagens = 'https://bigchef.com.br';

  @override
  void initState() {
    super.initState();
    _carregarBaseHostImagens();

    if (widget.editar == false) {
      listar();
    } else {
      itemProduto = widget.produto;
      _provedorProduto.opcoesPacotesListaFinal = widget.produto.opcoesPacotesListaFinal ?? [];
      _provedorProduto.valorVenda = double.parse(widget.produto.valorVenda);
      _provedorProduto.valorVendaOriginal = double.parse(widget.produto.valorVenda);
      _provedorProduto.calcularValorVenda(false, '0');
    }
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

  void listar() async {
    if (carregando == false) {
      setState(() {
        carregando = true;
      });
    }

    var inicioServico = Modular.get<ServicoProduto>();
    final idTamanhoPizza = widget.montagemPizza ? provedorCardapio.tamanhosPizza?.id ?? '0' : '0';
    await inicioServico.listarPorId(widget.produto.id, idTamanhoPizza).then((value) {
      itemProduto = value;
      if (value != null) {
        if (widget.valorVenda == null) {
          _provedorProduto.opcoesPacotesListaFinal = [for (var elm in value.opcoesPacotes!) ModeloOpcoesPacotes.fromMap(elm.toMap())].map((e) {
            // SE FOR KITS/COMBOS
            if (e.id == 2) {
              var a = e.produtos!.map((e1) {
                e1.opcoesPacotes?.map((e2) {
                  // se for acompanhamentos retorna todos
                  if (e2.id == 5) {
                    return e2;
                  }

                  // se for cortesia
                  if (e2.id == 1) {
                    e2.dados = e2.dados!.where((element) => element.estaSelecionado == true).toList();
                    return e2;
                  }

                  e2.dados = [];
                  return e2;
                }).toList();

                return e1;
              }).toList();

              e.produtos = a;

              return e;
            }

            // se for acompanhamentos retorna todos
            if (e.id == 5) {
              return e;
            }

            // se for cortesia
            if (e.id == 1) {
              e.dados = e.dados!.where((element) => element.estaSelecionado == true).toList();
              return e;
            }

            e.dados = [];

            return e;
          }).toList();

          _provedorProduto.valorVenda = double.parse(value.valorVenda);
          _provedorProduto.valorVendaOriginal = double.parse(value.valorVenda);
          _provedorProduto.calcularValorVenda(false, '0');
        }
      }
    }).whenComplete(() {
      setState(() {
        carregando = false;
      });
    });
  }

  void inserirNoCarrinho() async {
    final idComanda = provedorCardapio.idComanda;
    final idMesa = provedorCardapio.idMesa;

    var comanda = idComanda.isEmpty ? 0 : idComanda;
    var mesa = idMesa.isEmpty ? 0 : idMesa;
    var valor = itemProduto!.valorVenda;
    var idProduto = itemProduto!.id;
    var observacaoMesa = '';
    var observacao = obsController.text;

    if ((itemProduto?.opcoesPacotes?.where((element) => element.id == 4) ?? []).isNotEmpty && _provedorProduto.retornarDadosPorID([4], false, '0').isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um tamanho antes de continuar.'),
        showCloseIcon: true,
      ));

      return;
    }

    if ((itemProduto?.opcoesPacotes?.where((element) => element.id == 11) ?? []).isNotEmpty && _provedorProduto.retornarDadosPorID([11], false, '0').isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Selecione um sabor antes de continuar.'),
        showCloseIcon: true,
      ));

      return;
    }

    setState(() => carregando = !carregando);

    if (widget.montagemPizza && provedorCardapio.tamanhosPizza != null) {
      _provedorProduto.opcoesPacotesListaFinal.insert(
        0,
        ModeloOpcoesPacotes(
          id: 9,
          titulo: 'Tamanho Pizza',
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: provedorCardapio.tamanhosPizza!.id,
              nome: provedorCardapio.tamanhosPizza!.nomedotamanho,
              valor: provedorCardapio.calcularPrecoPizza().toStringAsFixed(2),
            )
          ],
        ),
      );

      _provedorProduto.opcoesPacotesListaFinal.insert(
        1,
        ModeloOpcoesPacotes(
            id: 10,
            titulo: 'Sabores Pizza (${provedorCardapio.saboresPizzaSelecionados.length})',
            obrigatorio: false,
            dados: provedorCardapio.saboresPizzaSelecionados
                .map((e) => ModeloDadosOpcoesPacotes(
                      id: e.id,
                      nome: e.nome,
                      codigo: e.codigo,
                      imprimirCodigoProdutoPreparo: e.imprimirCodigoProdutoPreparo,
                      valor: ((double.tryParse(provedorCardapio.valorSaborPizza(e)) ?? 0) / provedorCardapio.saboresPizzaSelecionados.length).toStringAsFixed(2),
                      quantimaximaselecao: '1/${provedorCardapio.saboresPizzaSelecionados.length}',
                    ))
                .toList()),
      );

      provedorCardapio.limiteSaborBordaSelecionado = -1;
      provedorCardapio.tamanhosPizza = null;
      provedorCardapio.saboresPizzaSelecionados = [];
    }

    itemProduto!.quantidade = _provedorProduto.quantidade.toDouble();
    itemProduto!.valorVenda = _provedorProduto.valorVenda.toStringAsFixed(2);
    itemProduto!.observacao = obsController.text;

    itemProduto!.opcoesPacotesListaFinal = _provedorProduto.opcoesPacotesListaFinal;

    if (obsController.text.isNotEmpty) {
      _provedorProduto.opcoesPacotesListaFinal.insert(
        _provedorProduto.opcoesPacotesListaFinal.length,
        ModeloOpcoesPacotes(
          id: 11,
          titulo: 'Observação',
          tipo: 7,
          obrigatorio: false,
          dados: [
            ModeloDadosOpcoesPacotes(
              id: '0',
              nome: obsController.text,
              foto: '',
              estaSelecionado: false,
              excluir: false,
            ),
          ],
        ),
      );
    }

    if (widget.inserirEmItensRecorrentes != null) {
      widget.inserirEmItensRecorrentes!(itemProduto!);
      Navigator.pop(context);
      return;
    }

    bool sucesso = false;

    if (widget.editar) {
      sucesso = await carrinhoProvedor.editar(itemProduto!, widget.indexProduto!);
    } else {
      sucesso = await carrinhoProvedor.inserir(
        itemProduto!,
        provedorCardapio.tipo.nome,
        mesa,
        comanda,
        valor,
        observacaoMesa,
        idProduto,
        itemProduto!.nome,
        itemProduto!.quantidade,
        observacao,
      );
    }

    if (sucesso) {
      _provedorProduto.resetarTudo();
      if (mounted) Navigator.pop(context);
      if (widget.valorVenda != null) {
        if (mounted) Navigator.pop(context);
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

    setState(() => carregando = !carregando);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (itemProduto == null) {
      if (carregando == false) {
        return Scaffold(
          appBar: AppBar(backgroundColor: cs.inversePrimary),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                Text('Produto não existe', style: theme.textTheme.titleMedium),
              ],
            ),
          ),
        );
      }

      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScopeNode currentFocus = FocusScope.of(context);
        if (!currentFocus.hasPrimaryFocus) {
          currentFocus.unfocus();
        }
      },
      child: AnimatedBuilder(
        animation: _provedorProduto,
        builder: (context, _) {
          final faixaPreco = (_provedorProduto.retornarDadosPorID([4], false, '0').isEmpty && _provedorProduto.retornarDadosPorID([4], false, '0').firstOrNull == null && itemProduto!.opcoesPacotes!.where((element) => element.id == 4).firstOrNull != null);
          final precoExibido = faixaPreco
              ? "${double.parse(itemProduto!.opcoesPacotes!.where((element) => element.id == 4).first.dados!.first.valor ?? '0').obterReal()} à ${double.parse(itemProduto!.opcoesPacotes!.where((element) => element.id == 4).first.dados!.last.valor ?? '0').obterReal()}"
              : (_provedorProduto.valorVenda).obterReal();
          final total = (_provedorProduto.valorVenda * _provedorProduto.quantidade).obterReal();

          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
            appBar: AppBar(
              backgroundColor: cs.inversePrimary,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.fastfood_outlined, size: 18, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "${itemProduto!.nome}${itemProduto!.tamanho.isNotEmpty ? ' ${itemProduto!.tamanho}' : ''}",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            bottomNavigationBar: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                child: BotaoAcaoPedido(
                  rotulo: 'Adicionar ao carrinho',
                  carregando: carregando,
                  quantidade: _provedorProduto.quantidade,
                  total: total,
                  onPressed: inserirNoCarrinho,
                ),
              ),
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 140),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // HERO: Imagem + Preço/Quantidade
                  _HeroProduto(
                    foto: itemProduto!.foto,
                    baseHost: _baseHostImagens,
                    descricao: itemProduto!.descricao,
                    quantidade: _provedorProduto.quantidade,
                    precoExibido: precoExibido,
                    total: total,
                    onDiminuir: _provedorProduto.aoDiminuirQuantidade,
                    onAumentar: _provedorProduto.aoAumentarQuantidade,
                  ),

                  // Seções: opções/pacotes
                  if (itemProduto!.opcoesPacotes!.isNotEmpty) ...[
                    ...itemProduto!.opcoesPacotes!.map((opcoesPacote) {
                      if (opcoesPacote.id == 6) return const SizedBox();
                      final count = opcoesPacote.id == 2 ? opcoesPacote.produtos!.length : opcoesPacote.dados!.length;

                      return Padding(
                        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                        child: _SecaoCard(
                          icon: _iconePorTipo(opcoesPacote.id),
                          titulo: opcoesPacote.titulo,
                          contagem: count,
                          obrigatorio: opcoesPacote.obrigatorio,
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: count,
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                            itemBuilder: (context, index) {
                              if (opcoesPacote.id == 2) {
                                return CardKit(item: opcoesPacote.produtos![index]);
                              }
                              return CardOpcoesPacotes(
                                opcoesPacote: opcoesPacote,
                                item: opcoesPacote.dados![index],
                                kit: false,
                                idProduto: '0',
                              );
                            },
                          ),
                        ),
                      );
                    }),
                  ],

                  // Observação
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    child: _SecaoCard(
                      icon: Icons.edit_note_rounded,
                      titulo: 'Observação do Produto',
                      contagem: null,
                      obrigatorio: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: TextField(
                          controller: obsController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            alignLabelWithHint: true,
                            hintText: "Ex.: Sem cebola, ponto da carne...",
                            hintStyle: TextStyle(
                              fontWeight: FontWeight.w300,
                              color: cs.onSurface.withValues(alpha: 0.5),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withValues(alpha: 0.04) : cs.surface,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: cs.outline.withValues(alpha: 0.25),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: cs.primary, width: 1.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconePorTipo(int? id) {
    switch (id) {
      case 1:
        return Icons.card_giftcard_rounded; // cortesia
      case 2:
        return Icons.inventory_2_outlined; // kits/combos
      case 4:
        return Icons.straighten_rounded; // tamanho
      case 5:
        return Icons.restaurant_menu_rounded; // acompanhamentos
      case 11:
        return Icons.local_pizza_rounded; // sabor
      default:
        return Icons.tune_rounded;
    }
  }
}

class _HeroProduto extends StatelessWidget {
  final String foto;
  final String baseHost;
  final String descricao;
  final int quantidade;
  final String precoExibido;
  final String total;
  final VoidCallback onDiminuir;
  final VoidCallback onAumentar;

  const _HeroProduto({
    required this.foto,
    required this.baseHost,
    required this.descricao,
    required this.quantidade,
    required this.precoExibido,
    required this.total,
    required this.onDiminuir,
    required this.onAumentar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : cs.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem
                Hero(
                  tag: 'foto_$foto',
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.04) : cs.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: foto.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(16),
                            child: Image.asset(Assets.boxAsset, fit: BoxFit.contain),
                          )
                        : CachedNetworkImage(
                            fit: BoxFit.contain,
                            fadeOutDuration: const Duration(milliseconds: 100),
                            placeholder: (context, url) => const Center(
                              child: SizedBox(
                                height: 28,
                                width: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.image_not_supported_outlined,
                              color: cs.onSurface.withValues(alpha: 0.4),
                            ),
                            imageUrl: UrlImagem.montarUrlImagem(
                              foto: foto,
                              baseHost: baseHost,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                // Coluna preço/total/quantidade
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StepperQuantidade(
                        quantidade: quantidade,
                        onDiminuir: onDiminuir,
                        onAumentar: onAumentar,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Preço unit.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.55),
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        precoExibido,
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.55),
                          letterSpacing: 0.4,
                        ),
                      ),
                      Text(
                        total,
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (descricao.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.03) : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16, color: cs.onSurface.withValues(alpha: 0.55)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        descricao,
                        maxLines: 6,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: cs.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepperQuantidade extends StatelessWidget {
  final int quantidade;
  final VoidCallback onDiminuir;
  final VoidCallback onAumentar;

  const _StepperQuantidade({
    required this.quantidade,
    required this.onDiminuir,
    required this.onAumentar,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final podeDiminuir = quantidade > 1;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : cs.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperBotao(
            icon: Icons.remove_rounded,
            enabled: podeDiminuir,
            color: Colors.red.shade400,
            onTap: onDiminuir,
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey(quantidade),
              constraints: const BoxConstraints(minWidth: 36),
              alignment: Alignment.center,
              child: Text(
                quantidade.toString(),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          _StepperBotao(
            icon: Icons.add_rounded,
            enabled: true,
            color: Colors.green.shade600,
            onTap: onAumentar,
          ),
        ],
      ),
    );
  }
}

class _StepperBotao extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTap;

  const _StepperBotao({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? color : Colors.grey.shade400,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _SecaoCard extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final int? contagem;
  final bool obrigatorio;
  final Widget child;

  const _SecaoCard({
    required this.icon,
    required this.titulo,
    required this.contagem,
    required this.obrigatorio,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : cs.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    titulo,
                    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
                  ),
                ),
                if (contagem != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$contagem',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: cs.primary,
                      ),
                    ),
                  ),
                ],
                if (obrigatorio) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Obrigatório',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}
