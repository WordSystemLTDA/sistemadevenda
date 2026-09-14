import 'dart:async';
import 'dart:developer';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/pagina_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/servicos/servicos_itens_recorrentes.dart';
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaItensRecorrentes extends StatefulWidget {
  final TipoCardapio tipo;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;
  final String? idCliente;

  const PaginaItensRecorrentes({
    super.key,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    this.idCliente,
    required this.tipo,
  });

  @override
  State<PaginaItensRecorrentes> createState() => _PaginaItensRecorrentesState();
}

class _PaginaItensRecorrentesState extends State<PaginaItensRecorrentes>
    with WidgetsBindingObserver {
  final ProvedorItensRecorrentes provedorItensRecorrentes =
      Modular.get<ProvedorItensRecorrentes>();
  final ServicosItensRecorrentes servicosItensRecorrentes =
      Modular.get<ServicosItensRecorrentes>();
  final Server _server = Modular.get<Server>();

  final TextEditingController _pesquisaController = TextEditingController();

  Modeloworddadoscardapio? dados;
  // ignore: unused_field
  Timer? _debounce;
  bool _carregando = false;
  String? _erroConsulta;

  @override
  void initState() {
    super.initState();
    provedorItensRecorrentes.selecionarAtendimento(
      idAtendimento: widget.idComandaPedido ?? '',
      tipo: widget.tipo.name,
      idRecurso: widget.tipo == TipoCardapio.mesa
          ? widget.idMesa ?? ''
          : widget.idComanda ?? '',
    );
    WidgetsBinding.instance.addObserver(this);
    _server.addListener(_aoReceberEventoSocket);
    listarComandasPedidos();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server.removeListener(_aoReceberEventoSocket);
    _pesquisaController.dispose();
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
    if (!mounted || _carregando) return;
    _carregando = true;
    setState(() => _erroConsulta = null);
    try {
      await provedorItensRecorrentes
          .listarComandasPedidos(widget.idComandaPedido ?? '0');
      final value = await servicosItensRecorrentes.listarPorId(
          widget.idComandaPedido ?? '0', widget.tipo, 'Sim');
      if (!mounted) return;
      setState(() {
        dados = value;
        _erroConsulta = null;
      });
    } catch (erro, stack) {
      log('Falha ao abrir itens recorrentes', error: erro, stackTrace: stack);
      if (!mounted) return;
      setState(() {
        dados = null;
        _erroConsulta =
            'Não foi possível carregar os itens recorrentes. Confira a conexão e tente novamente.';
      });
    } finally {
      _carregando = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    if (dados == null) {
      return Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
        appBar: _buildAppBar(context),
        body: _erroConsulta == null
            ? const Center(child: CircularProgressIndicator())
            : _buildErroConsulta(context),
      );
    }

    final produtos = dados?.produtos ?? const <Modelowordprodutos>[];
    final termo = _pesquisaController.text.toLowerCase();
    final produtosFiltrados = produtos.where((e) {
      return e.nome.toLowerCase().contains(termo) ||
          e.codigo.toLowerCase().contains(termo);
    }).toList();

    final totalProdutos = produtos.length;
    final emFechamento = dados?.status == 'Fechamento';

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
      appBar: _buildAppBar(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: _buildFloatingActions(context, emFechamento),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeaderInfo(context),
          _buildCampoPesquisa(context),
          if (produtosFiltrados.isEmpty)
            Expanded(child: _buildEstadoVazio(context, termo.isEmpty))
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 140, top: 4),
                itemCount: produtosFiltrados.length,
                itemBuilder: (context, index) {
                  final item = produtosFiltrados[index];
                  return CardItensRecorrentes(
                    estaPesquisando: false,
                    searchController: null,
                    item: item,
                    categoria: null,
                    finalizar: true,
                    idComanda: widget.idComanda ?? '0',
                    idMesa: widget.idMesa ?? '0',
                    idComandaPedido: widget.idComandaPedido ?? '0',
                  );
                },
              ),
            ),
          // contador discreto
          if (produtosFiltrados.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 24),
              child: Text(
                '${produtosFiltrados.length} de $totalProdutos itens',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                  color: cs.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return AppBar(
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
            child: Icon(Icons.repeat_rounded,
                size: 18, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 10),
          const Text(
            'Itens Recorrentes',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _identificacaoClientePedido() {
    final nomeCliente = dados?.nomeCliente?.trim() ?? '';
    final observacao = dados?.observacaoDoPedido?.trim() ?? '';
    final semCliente =
        nomeCliente.isEmpty || nomeCliente.toLowerCase() == 'sem cliente';

    if (semCliente && observacao.isNotEmpty) return observacao;
    if (semCliente) return 'Sem Cliente';
    return nomeCliente;
  }

  Widget _buildHeaderInfo(BuildContext context) {
    if (dados == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final emFechamento = dados!.status == 'Fechamento';
    final identificacaoCliente = _identificacaoClientePedido();

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : cs.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.tipo == TipoCardapio.mesa
                    ? Icons.table_restaurant_rounded
                    : Icons.receipt_long_rounded,
                color: cs.onPrimaryContainer,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    dados!.nome ?? '',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.person_outline_rounded,
                          size: 13,
                          color: cs.onSurface.withValues(alpha: 0.55)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          identificacaoCliente,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: cs.onSurface.withValues(alpha: 0.7),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (emFechamento)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Text(
                      'Fechamento',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.red,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCampoPesquisa(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : cs.outline.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_rounded,
                  color: cs.onSurface.withValues(alpha: 0.75)),
              tooltip: 'Voltar',
            ),
            Expanded(
              child: TextField(
                controller: _pesquisaController,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: 'Pesquisar produtos ou código...',
                  hintStyle: TextStyle(
                    fontSize: 13.5,
                    color: cs.onSurface.withValues(alpha: 0.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onTapOutside: (_) =>
                    FocusManager.instance.primaryFocus?.unfocus(),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            if (_pesquisaController.text.isNotEmpty)
              IconButton(
                onPressed: () {
                  _pesquisaController.clear();
                  setState(() {});
                },
                icon: Icon(Icons.close_rounded,
                    size: 20, color: cs.onSurface.withValues(alpha: 0.6)),
                tooltip: 'Limpar',
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Icon(Icons.search_rounded,
                    color: cs.onSurface.withValues(alpha: 0.45)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVazio(BuildContext context, bool semBusca) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              semBusca ? Icons.inventory_2_outlined : Icons.search_off_rounded,
              size: 44,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            semBusca ? 'Nenhum item recorrente' : 'Nenhum resultado',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            semBusca
                ? 'Compre itens para que apareçam aqui'
                : 'Tente buscar com outro termo',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErroConsulta(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.wifi_off_rounded,
                  color: cs.onErrorContainer, size: 40),
            ),
            const SizedBox(height: 16),
            Text(
              _erroConsulta ?? 'Não foi possível carregar.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                color: cs.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: listarComandasPedidos,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActions(BuildContext context, bool emFechamento) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botão comprar outros itens com gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (emFechamento) {
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${widget.tipo.nome} está em status de Fechamento',
                          textAlign: TextAlign.center),
                      backgroundColor: Colors.red,
                    ));
                    return;
                  }

                  if (widget.tipo == TipoCardapio.comanda) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaginaCardapio(
                            nomeAtendimento: dados?.nome,
                            tipo: TipoCardapio.comanda,
                            idComanda: dados?.idComanda,
                            idMesa: '0',
                            idCliente:
                                dados?.idCliente ?? widget.idCliente ?? '0',
                            id: widget.idComandaPedido,
                          ),
                        ));
                  } else if (widget.tipo == TipoCardapio.mesa) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaginaCardapio(
                            nomeAtendimento: dados?.nome,
                            tipo: TipoCardapio.mesa,
                            idComanda: '0',
                            idMesa: widget.idMesa,
                            idCliente:
                                dados?.idCliente ?? widget.idCliente ?? '0',
                            id: widget.idComandaPedido,
                          ),
                        ));
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_shopping_cart_rounded,
                          color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(
                        'Comprar outros itens',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Carrinho com badge
          AnimatedBuilder(
            animation: provedorItensRecorrentes,
            builder: (context, _) {
              final qtd = provedorItensRecorrentes.itensCarrinho.length;
              return badges.Badge(
                showBadge: qtd > 0,
                badgeContent: Text(
                  qtd.toString(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
                badgeStyle: const badges.BadgeStyle(
                  badgeColor: Colors.red,
                  padding: EdgeInsets.all(6),
                ),
                position: badges.BadgePosition.topEnd(top: -4, end: -4),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: cs.primary.withValues(alpha: 0.30),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) => PaginaCarrinhoItensRecorrentes(
                            idComanda: widget.idComanda ?? '0',
                            idComandaPedido: widget.idComandaPedido ?? '0',
                            idMesa: widget.idMesa ?? '0',
                            idCliente: widget.idCliente ?? '0',
                            tipo: widget.tipo,
                          ),
                        ));
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Icon(
                          Icons.shopping_cart_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
