// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:developer';

import 'package:app/src/modulos/cardapio/modelos/modelo_categoria.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/botao_carrinho.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/tab_custom.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/produto/paginas/pagina_sabor_bordas.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

enum TipoCardapio {
  comanda,
  mesa,
  delivery,
  balcao;

  String get nome {
    switch (this) {
      case TipoCardapio.comanda:
        return 'Comanda';
      case TipoCardapio.mesa:
        return 'Mesa';
      case TipoCardapio.delivery:
        return 'Delivery';
      case TipoCardapio.balcao:
        return 'Balcão';
    }
  }

  String get nomeSimplificado {
    switch (this) {
      case TipoCardapio.comanda:
        return 'comandas';
      case TipoCardapio.mesa:
        return 'mesas';
      case TipoCardapio.delivery:
        return 'delivery';
      case TipoCardapio.balcao:
        return 'balcao';
    }
  }
}

class PaginaCardapio extends StatefulWidget {
  final TipoCardapio tipo;
  final String? id;
  final String? idComanda;
  final String? idMesa;
  final String? idCliente;
  final String? tipodeentrega;

  const PaginaCardapio({
    super.key,
    required this.tipo,
    this.id,
    this.idComanda,
    this.idMesa,
    this.idCliente,
    this.tipodeentrega,
  });

  @override
  State<PaginaCardapio> createState() => _PaginaCardapioState();
}

class _PaginaCardapioState extends State<PaginaCardapio>
    with TickerProviderStateMixin {
  final ProvedorCardapio provedor = Modular.get<ProvedorCardapio>();
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();

  TabController? _tabController;
  List<ModeloCategoria> _categorias = [];
  int indexTabBar = 0;
  bool finalizar = false;
  bool _carregandoDados = false;
  String? _erroCarregamento;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      listarDados();
    });
  }

  @override
  void dispose() {
    _tabController?.removeListener(_aoTrocarCategoria);
    _tabController?.dispose();
    super.dispose();
  }

  void _aoTrocarCategoria() {
    final controller = _tabController;
    if (!mounted || controller == null || indexTabBar == controller.index) {
      return;
    }
    indexTabBar = controller.index;
    final categoria = _categorias[indexTabBar];
    if ((categoria.tamanhosPizza?.isEmpty ?? true) &&
        provedor.tamanhosPizza != null) {
      provedor.tamanhosPizza = null;
    }
  }

  Future<void> listarDados() async {
    if (!mounted || _carregandoDados) return;
    setState(() {
      _carregandoDados = true;
      _erroCarregamento = null;
    });
    try {
      setarCampos();
      await carrinhoProvedor.selecionarAtendimento(
        tipo: widget.tipo.name,
        idAtendimento: widget.id ?? '0',
        idRecurso: widget.tipo == TipoCardapio.mesa
            ? widget.idMesa ?? ''
            : widget.idComanda ?? '',
      );
      if (!mounted) return;
      if (_tabController == null) {
        final categorias = await provedor.listarCategorias();
        if (!mounted) return;
        setState(() {
          _categorias = List.of(categorias);
          if (_categorias.isNotEmpty) {
            _tabController =
                TabController(length: _categorias.length, vsync: this)
                  ..addListener(_aoTrocarCategoria);
          }
        });
      }
      await carrinhoProvedor.listarComandasPedidos();
      if (!mounted) return;
      await provedor.listarConfigBigChef();
    } catch (erro, stack) {
      log('Falha ao carregar o cardapio', error: erro, stackTrace: stack);
      if (mounted) {
        setState(() => _erroCarregamento =
            'Não foi possível carregar o cardápio. Confira a conexão e tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _carregandoDados = false);
    }
  }

  void setarCampos() {
    provedor.tamanhosPizza = null;
    provedor.tipo = widget.tipo;
    provedor.idComanda = widget.idComanda ?? '0';
    provedor.idMesa = widget.idMesa ?? '0';
    provedor.idCliente = widget.idCliente ?? '0';
    provedor.id = widget.id ?? '0';
    provedor.tipodeentrega = widget.tipodeentrega ?? '0';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: provedor,
      builder: (context, _) {
        final temCategorias = _tabController != null && _categorias.isNotEmpty;
        return Scaffold(
          extendBody: true,
          backgroundColor: cs.surface,
          appBar: AppBar(
            backgroundColor: cs.inversePrimary,
            elevation: 0,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.restaurant_menu_rounded,
                      color: cs.onPrimaryContainer, size: 18),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Cardápio',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1)),
                    Text(widget.tipo.nome,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
            bottom: !temCategorias
                ? PreferredSize(
                    preferredSize: Size.fromHeight(48),
                    child: SizedBox(
                        height: 48,
                        child: _carregandoDados
                            ? const Align(
                                alignment: Alignment.bottomCenter,
                                child: LinearProgressIndicator())
                            : null),
                  )
                : TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    tabs: [
                      ..._categorias.map((e) => Tab(text: e.nomeCategoria)),
                    ],
                  ),
          ),
          bottomNavigationBar: AnimatedBuilder(
            animation: Listenable.merge([provedor, carrinhoProvedor]),
            builder: (context, _) {
              final temPizza = provedor.tamanhosPizza != null &&
                  provedor.saboresPizzaSelecionados.isNotEmpty;
              final quantidadeSabores =
                  provedor.saboresPizzaSelecionados.length;
              return SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                  child: Row(
                    children: [
                      if (temPizza) ...[
                        Expanded(
                          child: BotaoAcaoPedido(
                            rotulo: 'Avançar ($quantidadeSabores)',
                            total: provedor.calcularPrecoPizza().obterReal(),
                            onPressed: () {
                              if (!context.mounted) return;
                              final item = provedor.saboresPizzaSelecionados[0];
                              Navigator.of(context).push(MaterialPageRoute(
                                builder: (context) => PaginaSaborBordas(
                                  produto: item,
                                  valorVenda: provedor.calcularPrecoPizza(),
                                ),
                              ));
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                      ] else
                        const Spacer(),
                      BotaoCarrinho(
                        key: const ValueKey('carrinho_cardapio'),
                        quantidade:
                            carrinhoProvedor.itensCarrinho.quantidadeTotal,
                        numeroAdicoes: carrinhoProvedor.numeroAdicoes,
                        onPressed: () {
                          if (_carregandoDados) return;
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) => const PaginaCarrinho(),
                          ));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          body: Column(
            children: [
              if (_erroCarregamento != null && temCategorias)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: _estadoCarregamento(),
                ),
              Expanded(
                child: !temCategorias
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: _estadoCarregamento(),
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          for (final categoria in _categorias)
                            TabCustom(
                              key: ValueKey(categoria.id),
                              category: categoria.id,
                              categoria: categoria,
                              finalizar: finalizar,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _estadoCarregamento() {
    if (_carregandoDados) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _erroCarregamento ?? 'Nenhuma categoria encontrada',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: listarDados,
          icon: const Icon(Icons.refresh),
          label: Text(
              _erroCarregamento == null ? 'Atualizar' : 'Tentar novamente'),
        ),
      ],
    );
  }
}
