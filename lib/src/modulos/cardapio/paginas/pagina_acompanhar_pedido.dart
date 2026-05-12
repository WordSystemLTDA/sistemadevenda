import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_produto_acompanhar.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaAcompanharPedido extends StatefulWidget {
  final TipoCardapio tipo;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;

  const PaginaAcompanharPedido({
    super.key,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    required this.tipo,
  });

  @override
  State<PaginaAcompanharPedido> createState() => _PaginaAcompanharPedidoState();
}

class _PaginaAcompanharPedidoState extends State<PaginaAcompanharPedido> with WidgetsBindingObserver {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final Server _server = Modular.get<Server>();

  Modeloworddadoscardapio? dados;
  bool _carregando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _server.addListener(_aoReceberEventoSocket);
    listarComandasPedidos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server.removeListener(_aoReceberEventoSocket);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      listarComandasPedidos();
    }
  }

  void _aoReceberEventoSocket() {
    if (!mounted || _carregando) return;
    listarComandasPedidos();
  }

  Future<void> listarComandasPedidos() async {
    if (_carregando) return;
    _carregando = true;
    await servicoCardapio.listarPorId(widget.idComandaPedido ?? '0', TipoCardapio.comanda, 'Sim').then((value) {
      if (!mounted) return;
      setState(() {
        dados = value;
      });
    });
    _carregando = false;
  }

  String get _nomeTipo {
    if (widget.idComandaPedido != null) return 'Comanda';
    if (widget.idMesa != null) return 'Mesa';
    return '';
  }

  IconData get _iconeTipo {
    if (widget.idComandaPedido != null) return Icons.receipt_long_rounded;
    if (widget.idMesa != null) return Icons.table_restaurant_rounded;
    return Icons.assignment_outlined;
  }

  int _totalItens(List<Modelowordprodutos> produtos) {
    var total = 0.0;
    for (final p in produtos) {
      total += (p.quantidade ?? 0);
    }
    return total.toInt();
  }

  double _valorTotal(List<Modelowordprodutos> produtos) {
    var total = 0.0;
    for (final p in produtos) {
      total += (double.tryParse(p.valorVenda) ?? 0) * (p.quantidade ?? 0);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (dados == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: _construirAppBar(cs),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final produtos = dados!.produtos ?? <Modelowordprodutos>[];
    final totalItens = _totalItens(produtos);
    final valorTotal = _valorTotal(produtos);

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: _construirAppBar(cs),
      body: RefreshIndicator(
        onRefresh: listarComandasPedidos,
        child: produtos.isEmpty
            ? _EstadoVazio(cs: cs)
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: [
                  _HeroCard(
                    cs: cs,
                    icone: _iconeTipo,
                    rotulo: _nomeTipo.toUpperCase(),
                    titulo: dados!.nome ?? '',
                    subtitulo: dados!.nomeCliente ?? 'Sem cliente',
                    numeroPedido: dados!.numeroPedido,
                  ),
                  const SizedBox(height: 14),
                  _ResumoChips(cs: cs, totalItens: totalItens, valorTotal: valorTotal),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 8),
                    child: Row(
                      children: [
                        Icon(Icons.list_alt_rounded, size: 18, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          'ITENS DO PEDIDO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ...produtos.map((item) {
                    return CardProdutoAcompanhar(
                      item: item,
                      dados: dados,
                      idComanda: widget.idComanda ?? '0',
                      idComandaPedido: widget.idComandaPedido ?? '0',
                      idMesa: widget.idMesa ?? '0',
                      setarQuantidade: (increase) {},
                      value: '',
                      tipo: widget.tipo,
                    );
                  }),
                ],
              ),
      ),
      bottomNavigationBar: produtos.isEmpty ? null : _RodapeTotal(cs: cs, valorTotal: valorTotal, totalItens: totalItens),
    );
  }

  PreferredSizeWidget _construirAppBar(ColorScheme cs) {
    return AppBar(
      backgroundColor: cs.inversePrimary,
      elevation: 0,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconeTipo, color: cs.onPrimaryContainer, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Detalhes da $_nomeTipo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1),
              ),
              Text(
                'Acompanhamento do pedido',
                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Atualizar',
          onPressed: listarComandasPedidos,
          icon: const Icon(Icons.refresh_rounded),
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  final ColorScheme cs;
  final IconData icone;
  final String rotulo;
  final String titulo;
  final String subtitulo;
  final String? numeroPedido;

  const _HeroCard({
    required this.cs,
    required this.icone,
    required this.rotulo,
    required this.titulo,
    required this.subtitulo,
    this.numeroPedido,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.primaryContainer.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surface.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icone, color: cs.onPrimaryContainer, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      rotulo,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: cs.onPrimaryContainer.withValues(alpha: 0.75),
                      ),
                    ),
                    if (numeroPedido != null && numeroPedido!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: cs.surface.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '#$numeroPedido',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: cs.onPrimaryContainer,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded, size: 14, color: cs.onPrimaryContainer.withValues(alpha: 0.85)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        subtitulo.isEmpty ? 'Sem cliente' : subtitulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ResumoChips extends StatelessWidget {
  final ColorScheme cs;
  final int totalItens;
  final double valorTotal;

  const _ResumoChips({required this.cs, required this.totalItens, required this.valorTotal});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Chip(
            cs: cs,
            icone: Icons.shopping_bag_outlined,
            rotulo: 'Itens',
            valor: totalItens.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: _Chip(
            cs: cs,
            icone: Icons.payments_outlined,
            rotulo: 'Total parcial',
            valor: valorTotal.obterReal(),
            destaque: true,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final ColorScheme cs;
  final IconData icone;
  final String rotulo;
  final String valor;
  final bool destaque;

  const _Chip({
    required this.cs,
    required this.icone,
    required this.rotulo,
    required this.valor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: destaque ? cs.secondaryContainer : cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icone, size: 18, color: destaque ? cs.onSecondaryContainer : cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  rotulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: destaque ? cs.onSecondaryContainer.withValues(alpha: 0.85) : cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  valor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: destaque ? cs.onSecondaryContainer : cs.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RodapeTotal extends StatelessWidget {
  final ColorScheme cs;
  final double valorTotal;
  final int totalItens;

  const _RodapeTotal({required this.cs, required this.valorTotal, required this.totalItens});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.6)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.receipt_outlined, color: cs.onPrimaryContainer, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Total ($totalItens ${totalItens == 1 ? "item" : "itens"})',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(
                  valorTotal.obterReal(),
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.primary, letterSpacing: 0.2),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final ColorScheme cs;
  const _EstadoVazio({required this.cs});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.receipt_long_outlined, size: 52, color: cs.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            'Nenhum item lançado',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
            'Os itens aparecerão aqui assim que forem lançados.',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
