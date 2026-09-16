import 'dart:async';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/utils/dados_impressao_preparo.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_produto.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_detalhes_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/pagina_novo_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/busca_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/filtros_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/pagamento_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/menu_pedido_delivery.dart';
import 'package:app/src/modulos/delivery/paginas/widgets/acoes_menu_delivery.dart';
import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/impressao_delivery.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaDelivery extends StatefulWidget {
  final ProvedorDelivery? provedor;
  const PaginaDelivery({super.key, this.provedor});
  @override
  State<PaginaDelivery> createState() => _PaginaDeliveryState();
}

class _PaginaDeliveryState extends State<PaginaDelivery>
    with WidgetsBindingObserver {
  late final _provedor =
      widget.provedor ?? ProvedorDelivery(Modular.get<ServicoDelivery>());
  final _busca = TextEditingController();
  Timer? _debounce, _timer;
  StreamSubscription<PedidoDelivery>? _atualizacoes;
  bool _rotaAberta = false, _ativo = true;
  String? _ocupado;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _atualizacoes = ServicoDelivery.pedidosAtualizados.listen((pedido) {
      if (!mounted) return;
      _provedor.atualizarPedido(pedido);
    });
    _provedor.listar();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_ativo &&
          !_rotaAberta &&
          _ocupado == null &&
          !_provedor.carregando &&
          ModalRoute.of(context)?.isCurrent == true) {
        _provedor.listar();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _ativo = state == AppLifecycleState.resumed;
    if (_ativo && !_rotaAberta && _ocupado == null && !_provedor.carregando) {
      _provedor.listar();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _debounce?.cancel();
    _atualizacoes?.cancel();
    _busca.dispose();
    if (widget.provedor == null) _provedor.dispose();
    super.dispose();
  }

  Future<void> _abrir(Widget pagina) async {
    _rotaAberta = true;
    FocusManager.instance.primaryFocus?.unfocus();
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => pagina));
    } finally {
      _rotaAberta = false;
      if (mounted) await _provedor.listar();
    }
  }

  Future<void> _cardapio(PedidoDelivery pedido) => _abrir(PaginaCardapio(
        tipo: TipoCardapio.delivery,
        id: pedido.id,
        idCliente: pedido.cliente,
        tipodeentrega: pedido.tipoEntrega,
        nomeAtendimento: 'Delivery #${pedido.numero}',
      ));
  void _mensagem(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(texto)));
  }

  Future<void> _menu(PedidoDelivery pedido, EtapaDelivery etapa) async {
    if (_ocupado != null || _rotaAberta) return;
    _rotaAberta = true;
    try {
      final acao = await mostrarMenuPedidoDelivery(context, pedido, etapa);
      if (acao == null || !mounted) return;
      setState(() => _ocupado = pedido.id);
      final atual = await _provedor.servico.pedido(pedido.id);
      if (!mounted) return;
      await executarAcaoDelivery(context, _provedor.servico, atual, acao);
    } catch (e) {
      _mensagem(e is StateError
          ? e.message.toString()
          : 'Não foi possível confirmar a ação. Atualize o pedido antes de tentar novamente.');
    } finally {
      _rotaAberta = false;
      if (mounted) {
        setState(() => _ocupado = null);
        await _provedor.listar();
      }
    }
  }

  Future<void> _avancar(PedidoDelivery pedido, EtapaDelivery origem,
      EtapaDelivery? destino) async {
    if (_ocupado != null) return;
    if (pedido.quantidade == 0) {
      await _cardapio(pedido);
      return;
    }
    setState(() => _ocupado = pedido.id);
    bool alterado = false;
    try {
      var atual = await _provedor.servico.pedido(pedido.id);
      if (!mounted) return;
      if (!atual.podeAvancar(origem) || atual.etapa != origem.id) {
        throw StateError(
            'O pedido foi atualizado em outro aparelho. Confira a etapa atual.');
      }
      final alvo = destino ?? origem;
      final config = await _provedor.servico.configuracao();
      if (!mounted) return;
      if (config.exigePagamento(atual, alvo)) {
        final recebeu =
            await receberDelivery(context, _provedor.servico, atual.id);
        if (recebeu != true || !mounted) return;
        atual = await _provedor.servico.pedido(pedido.id);
        if (atual.restante > .009) {
          _mensagem(
              'Pagamento parcial registrado. Falta ${atual.restante.obterReal()}.');
          return;
        }
        if (atual.etapa != origem.id || !atual.podeAvancar(origem)) {
          throw StateError('O pedido foi atualizado. Confira a etapa atual.');
        }
      }
      if (!mounted) return;
      String entregador = config.entregadorFixo,
          taxa = atual.texto('valordaentrega', '0');
      if (atual.tipoEntrega == '1' &&
          alvo.selecionarEntregador &&
          entregador.isEmpty) {
        final res = await buscarDelivery(context,
            titulo: 'Selecionar entregador',
            buscar: (termo) async => [
                  for (final e in await _provedor.servico.consultar(
                      'entregador/listar_por_nome.php',
                      {'pesquisa': termo, 'cliente': '0'}) as List)
                    Map<String, dynamic>.from(e as Map)
                ],
            nome: (e) => '${e['nomecompleto'] ?? e['nome']}',
            detalhe: (e) => '${e['telefone'] ?? ''}');
        if (res == null || !mounted) return;
        entregador = '${res['id']}';
      }
      // Revalida depois dos diálogos, antes de efetivar a mudança de etapa.
      final conferido = await _provedor.servico.pedido(pedido.id);
      if (!conferido.podeAvancar(origem) ||
          conferido.etapa != origem.id ||
          (conferido.total - atual.total).abs() > .009 ||
          config.exigePagamento(conferido, alvo)) {
        throw StateError('O pedido mudou. Confira os dados antes de avançar.');
      }
      if (alvo.impressao == '3' && !conferido.encerrado) {
        await _provedor.servico.concluir(conferido);
      }
      if (destino != null) {
        final res = await _provedor.servico.avancar(conferido, alvo,
            entregador: entregador, valorEntrega: taxa);
        if (res['ativarselecaoentregador'] == 'Sim' && entregador.isEmpty) {
          throw StateError(
              'Esta etapa exige um entregador. Confira a configuração do Delivery.');
        }
        alterado = true;
        final atualizado = await _provedor.servico.pedido(pedido.id);
        if (atualizado.etapa != alvo.id) {
          throw StateError('Não foi possível confirmar a etapa de destino.');
        }
      }
      final paraImprimir = await _provedor.servico.pedido(pedido.id);
      if (['1', '4'].contains(alvo.impressao) && config.imprimirPreparo) {
        await ImpressaoDelivery.imprimir(
            _provedor.servico, Modular.get<Server>(), paraImprimir,
            preparo: true);
      }
      if (['2', '4'].contains(alvo.impressao)) {
        await ImpressaoDelivery.imprimir(
            _provedor.servico, Modular.get<Server>(), paraImprimir);
      }
    } catch (e) {
      _mensagem(alterado
          ? 'Etapa atualizada, mas há uma pendência. Confira o pedido e a fila de impressão.'
          : e is StateError
              ? e.message.toString()
              : 'Não foi possível confirmar a alteração. Atualize o Delivery.');
    } finally {
      if (mounted) {
        setState(() => _ocupado = null);
        await _provedor.listar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
          title: const Text('Delivery'),
          backgroundColor: cs.inversePrimary,
          actions: [
            IconButton(
                tooltip: 'Atualizar pedidos',
                onPressed: _ocupado == null ? _provedor.listar : null,
                icon: const Icon(Icons.refresh)),
          ]),
      floatingActionButton: _BotaoNovoPedido(
          habilitado: _ocupado == null,
          onPressed: () =>
              _abrir(PaginaNovoDelivery(servico: _provedor.servico))),
      body: ListenableBuilder(
          listenable: _provedor,
          builder: (context, child) {
            final filtros = Column(children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  child: Row(children: [
                    Expanded(
                        child: TextField(
                      controller: _busca,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                          hintText: 'Pedido, cliente ou telefone',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _busca.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: 'Limpar busca',
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    _debounce?.cancel();
                                    _busca.clear();
                                    _provedor.pesquisa = '';
                                    _provedor.listar();
                                  }),
                          isDense: true,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                      onChanged: (v) {
                        setState(() {});
                        _debounce?.cancel();
                        _provedor.pesquisa = v.trim();
                        _debounce = Timer(const Duration(milliseconds: 350),
                            _provedor.listar);
                      },
                      onSubmitted: (_) {
                        _debounce?.cancel();
                        _provedor.listar();
                      },
                    )),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                        tooltip: 'Filtrar período e entrega',
                        icon: const Icon(Icons.tune),
                        onPressed: () async {
                          final aplicar = await showDialog<bool>(
                              context: context,
                              builder: (_) =>
                                  FiltrosDelivery(provedor: _provedor));
                          if (mounted && aplicar == true) _provedor.listar();
                        }),
                  ])),
              Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            '${DateFormat('dd/MM').format(_provedor.periodo.start)} - ${DateFormat('dd/MM').format(_provedor.periodo.end)} · ${_provedor.horaInicio.substring(0, 5)}',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 12))),
                    Text(
                        '${_provedor.etapas.fold<int>(0, (s, e) => s + e.pedidos.length)} pedidos',
                        style: const TextStyle(fontSize: 12)),
                  ])),
              SizedBox(
                  height: 2,
                  child: _provedor.carregando
                      ? const LinearProgressIndicator(minHeight: 2)
                      : null),
              if (_provedor.erro != null)
                Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(children: [
                      Expanded(
                          child: Text(_provedor.erro!,
                              style: TextStyle(color: cs.error))),
                      IconButton(
                          tooltip: 'Tentar novamente',
                          onPressed: _provedor.listar,
                          icon: const Icon(Icons.refresh)),
                    ])),
            ]);
            if (_provedor.etapas.isEmpty) {
              return Column(children: [
                filtros,
                Expanded(
                    child: Center(
                        child: _provedor.carregando
                            ? const CircularProgressIndicator()
                            : Text(_provedor.erro == null
                                ? 'Nenhuma etapa de Delivery cadastrada'
                                : 'Delivery indisponível')))
              ]);
            }
            return _CarrosselDelivery(
              etapas: _provedor.etapas,
              filtros: filtros,
              atualizar: _provedor.listar,
              ocupado: _ocupado,
              abrir: (p) => _abrir(
                  PaginaDetalhesDelivery(servico: _provedor.servico, id: p.id)),
              avancar: _avancar,
              opcoes: _menu,
              config: _provedor.config,
            );
          }),
    );
  }
}

class _CarrosselDelivery extends StatefulWidget {
  final List<EtapaDelivery> etapas;
  final Widget filtros;
  final String? ocupado;
  final ConfigDelivery? config;
  final Future<void> Function() atualizar;
  final Future<void> Function(PedidoDelivery) abrir;
  final Future<void> Function(PedidoDelivery, EtapaDelivery) opcoes;
  final Future<void> Function(PedidoDelivery, EtapaDelivery, EtapaDelivery?)
      avancar;
  const _CarrosselDelivery(
      {required this.etapas,
      required this.filtros,
      required this.atualizar,
      required this.abrir,
      required this.avancar,
      required this.opcoes,
      this.ocupado,
      this.config});
  @override
  State<_CarrosselDelivery> createState() => _CarrosselDeliveryState();
}

class _CarrosselDeliveryState extends State<_CarrosselDelivery>
    with TickerProviderStateMixin {
  late TabController _abas =
      TabController(length: widget.etapas.length, vsync: this);
  final _produtosExpandidos = <String>{};

  @override
  void didUpdateWidget(covariant _CarrosselDelivery old) {
    super.didUpdateWidget(old);
    if (old.etapas.map((e) => e.id).join(',') !=
        widget.etapas.map((e) => e.id).join(',')) {
      final id = old.etapas[_abas.index].id;
      final indice = widget.etapas.indexWhere((e) => e.id == id);
      final anterior = _abas;
      _abas = TabController(
          length: widget.etapas.length,
          vsync: this,
          initialIndex: indice < 0 ? 0 : indice);
      WidgetsBinding.instance.addPostFrameCallback((_) => anterior.dispose());
    }
  }

  @override
  void dispose() {
    _abas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      Material(
        color: cs.inversePrimary,
        child: TabBar(
          controller: _abas,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            for (final e in widget.etapas)
              Tab(text: '${e.nome} (${e.pedidos.length})')
          ],
        ),
      ),
      widget.filtros,
      Expanded(
          child: TabBarView(controller: _abas, children: [
        for (var i = 0; i < widget.etapas.length; i++)
          Builder(builder: (_) {
            final etapa = widget.etapas[i];
            final destino =
                etapa.impressao != '3' && i + 1 < widget.etapas.length
                    ? widget.etapas[i + 1]
                    : null;
            return Column(children: [
              Expanded(
                  child: RefreshIndicator(
                      onRefresh: widget.atualizar,
                      child: ListView.builder(
                          key: PageStorageKey('delivery-${etapa.id}'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
                          itemCount:
                              etapa.pedidos.isEmpty ? 1 : etapa.pedidos.length,
                          itemBuilder: (_, j) {
                            if (etapa.pedidos.isEmpty) {
                              return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 64),
                                  child: Column(children: [
                                    Icon(Icons.receipt_long_outlined,
                                        size: 42, color: cs.outline),
                                    const SizedBox(height: 12),
                                    const Text('Nenhum pedido nesta etapa'),
                                  ]));
                            }
                            final p = etapa.pedidos[j];
                            final idade = p.abertura == null
                                ? ''
                                : '${DateTime.now().difference(p.abertura!).inMinutes.clamp(0, 99999)} min';
                            final label = p.quantidade == 0
                                ? 'Adicionar produtos'
                                : widget.config?.exigePagamento(
                                            p, destino ?? etapa) ==
                                        true
                                    ? 'Receber ${p.restante.obterReal()}'
                                    : etapa.impressao == '3'
                                        ? 'Concluir pedido'
                                        : etapa.botao;
                            final podeAvancar =
                                p.podeAvancar(etapa) && destino != null;
                            final produtos = p.produtos;
                            final podeMostrarProdutos =
                                p.quantidade > 0 && produtos.isNotEmpty;
                            final produtosAbertos =
                                _produtosExpandidos.contains(p.id);
                            return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                color: cs.surfaceContainerLowest,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: cs.outlineVariant)),
                                child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: widget.ocupado == null
                                        ? () => widget.abrir(p)
                                        : null,
                                    child: Padding(
                                        padding: const EdgeInsets.all(14),
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(children: [
                                                Expanded(
                                                    child: Text('#${p.numero}',
                                                        style: TextStyle(
                                                            color: cs.primary,
                                                            fontWeight:
                                                                FontWeight
                                                                    .bold))),
                                                Icon(
                                                    p.tipoEntrega == '1'
                                                        ? Icons.delivery_dining
                                                        : Icons
                                                            .shopping_bag_outlined,
                                                    size: 18,
                                                    color: cs.onSurfaceVariant),
                                                const SizedBox(width: 5),
                                                Text(p.nomeEntrega,
                                                    style: TextStyle(
                                                        fontSize: 12,
                                                        color: cs
                                                            .onSurfaceVariant)),
                                                const SizedBox(width: 8),
                                                IconButton(
                                                    tooltip:
                                                        'Opções do pedido #${p.numero}',
                                                    onPressed: widget.ocupado ==
                                                            null
                                                        ? () => widget.opcoes(
                                                            p, etapa)
                                                        : null,
                                                    icon: const Icon(
                                                        Icons.more_vert,
                                                        size: 20)),
                                              ]),
                                              const SizedBox(height: 10),
                                              if (etapa.impressao == '3')
                                                Text('Concluído',
                                                    style: TextStyle(
                                                        color: cs.primary,
                                                        fontSize: 12)),
                                              Text(p.nome,
                                                  style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                              if (p.tipoEntrega == '1' &&
                                                  p.endereco.isNotEmpty)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(p.endereco,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                            fontSize: 13,
                                                            color: cs
                                                                .onSurfaceVariant))),
                                              const SizedBox(height: 12),
                                              Row(children: [
                                                Expanded(
                                                    child: Text(
                                                        '${p.quantidade} itens${idade.isEmpty ? '' : ' · $idade'}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color: cs
                                                                .onSurfaceVariant))),
                                                Text(p.total.obterReal(),
                                                    style: const TextStyle(
                                                        fontSize: 17,
                                                        fontWeight:
                                                            FontWeight.bold))
                                              ]),
                                              if (p.tipoEntrega == '1')
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 6),
                                                  child: Text(
                                                      'Entrega: ${p.taxaEntrega.obterReal()}',
                                                      style: TextStyle(
                                                          fontSize: 12,
                                                          color: cs
                                                              .onSurfaceVariant)),
                                                ),
                                              if (podeMostrarProdutos) ...[
                                                const SizedBox(height: 10),
                                                _BotaoPreviewProdutos(
                                                  aberto: produtosAbertos,
                                                  quantidade: produtos.length,
                                                  onTap: () => setState(() {
                                                    if (produtosAbertos) {
                                                      _produtosExpandidos
                                                          .remove(p.id);
                                                    } else {
                                                      _produtosExpandidos
                                                          .add(p.id);
                                                    }
                                                  }),
                                                ),
                                                AnimatedCrossFade(
                                                  firstChild:
                                                      const SizedBox.shrink(),
                                                  secondChild:
                                                      _PreviewProdutosPedido(
                                                          produtos: produtos),
                                                  crossFadeState:
                                                      produtosAbertos
                                                          ? CrossFadeState
                                                              .showSecond
                                                          : CrossFadeState
                                                              .showFirst,
                                                  duration: const Duration(
                                                      milliseconds: 180),
                                                  firstCurve:
                                                      Curves.easeOutCubic,
                                                  secondCurve:
                                                      Curves.easeOutCubic,
                                                  sizeCurve:
                                                      Curves.easeOutCubic,
                                                ),
                                              ],
                                              if (p.pago > 0)
                                                Padding(
                                                    padding:
                                                        const EdgeInsets.only(
                                                            top: 6),
                                                    child: Text(
                                                        p.restante <= .009
                                                            ? 'Pagamento registrado'
                                                            : 'A receber ${p.restante.obterReal()}',
                                                        style: TextStyle(
                                                            fontSize: 12,
                                                            color:
                                                                cs.primary))),
                                              if (podeAvancar) ...[
                                                const SizedBox(height: 12),
                                                SizedBox(
                                                    width: double.infinity,
                                                    child: FilledButton.icon(
                                                      onPressed: widget
                                                                  .ocupado !=
                                                              null
                                                          ? null
                                                          : () => widget.avancar(
                                                              p,
                                                              etapa,
                                                              etapa.impressao ==
                                                                      '3'
                                                                  ? null
                                                                  : destino),
                                                      icon: widget.ocupado ==
                                                              p.id
                                                          ? const SizedBox(
                                                              width: 18,
                                                              height: 18,
                                                              child:
                                                                  CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2))
                                                          : const Icon(
                                                              Icons
                                                                  .arrow_forward,
                                                              size: 18),
                                                      label: Text(
                                                          widget.ocupado == p.id
                                                              ? 'Aguarde...'
                                                              : label,
                                                          textAlign:
                                                              TextAlign.center),
                                                      style: FilledButton.styleFrom(
                                                          minimumSize:
                                                              const Size(0, 44),
                                                          shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          8))),
                                                    ))
                                              ],
                                            ]))));
                          }))),
            ]);
          })
      ])),
    ]);
  }
}

class _BotaoPreviewProdutos extends StatelessWidget {
  final bool aberto;
  final int quantidade;
  final VoidCallback onTap;
  const _BotaoPreviewProdutos(
      {required this.aberto, required this.quantidade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: .45),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(children: [
            Icon(Icons.receipt_long_outlined, size: 18, color: cs.primary),
            const SizedBox(width: 8),
            Expanded(
                child: Text(
              aberto
                  ? 'Ocultar itens'
                  : 'Ver itens ($quantidade ${quantidade == 1 ? 'item' : 'itens'})',
              style: TextStyle(
                  color: cs.primary, fontSize: 13, fontWeight: FontWeight.w600),
            )),
            Icon(
              aberto
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: cs.primary,
            ),
          ]),
        ),
      ),
    );
  }
}

class _PreviewProdutosPedido extends StatelessWidget {
  final List<Modelowordprodutos> produtos;
  const _PreviewProdutosPedido({required this.produtos});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(8),
        border: Border(left: BorderSide(color: cs.primary, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final produto in produtos)
            _LinhaPreviewProduto(produto: produto),
        ],
      ),
    );
  }
}

class _LinhaPreviewProduto extends StatelessWidget {
  final Modelowordprodutos produto;
  const _LinhaPreviewProduto({required this.produto});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dados = DadosImpressaoPreparo.produto(produto);
    final detalhes = _detalhes(dados);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            constraints: const BoxConstraints(minWidth: 28),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: .55),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_formatarQuantidade(produto.quantidade)}x',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                _texto(dados['nome']).isEmpty
                    ? produto.nome
                    : _texto(dados['nome']),
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (detalhes.isNotEmpty) ...[
                const SizedBox(height: 2),
                for (final detalhe in detalhes)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      detalhe,
                      style:
                          TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ),
              ],
            ]),
          ),
          const SizedBox(width: 8),
          Text(
            valorDelivery(produto.valorTotalVendas ?? produto.valorVenda)
                .obterReal(),
            style: TextStyle(
                color: cs.primary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ]),
      ]),
    );
  }

  List<String> _detalhes(Map<String, dynamic> dados) {
    final linhas = <String>[];
    for (final opcao in [
      ..._lista(dados['opcoesPacotesListaFinal']),
      ..._lista(dados['opcoesPacotes']),
    ]) {
      final titulo = _texto(opcao['titulo']);
      final partes = <String>[
        for (final dado in _lista(opcao['dados'])) _nomeDado(dado).trim(),
        for (final produto in _lista(opcao['produtos']))
          _texto(produto['nome']).trim(),
      ]..removeWhere((parte) => parte.isEmpty);
      if (partes.isEmpty) continue;
      linhas.add('${titulo.isEmpty ? 'Opções' : titulo}: ${partes.join(', ')}');
    }
    final observacao = _texto(dados['observacao']).trim();
    if (observacao.isNotEmpty) linhas.add('Obs: $observacao');
    return linhas;
  }

  String _nomeDado(Map<String, dynamic> dado) {
    final nome = _texto(dado['nome']);
    final quantidade = dado['quantidade'];
    final qtd = quantidade is num
        ? quantidade.toInt()
        : int.tryParse((quantidade ?? '').toString()) ?? 0;
    return qtd > 1 ? '${qtd}x $nome' : nome;
  }
}

List<Map<String, dynamic>> _lista(Object? valor) {
  if (valor is! List) return const [];
  return [
    for (final item in valor)
      if (item is Map) Map<String, dynamic>.from(item)
  ];
}

String _texto(Object? valor) => valor?.toString() ?? '';

String _formatarQuantidade(double? valor) {
  final quantidade = valor ?? 1;
  if (quantidade == quantidade.roundToDouble()) {
    return quantidade.toInt().toString();
  }
  return quantidade.toStringAsFixed(2).replaceAll('.', ',');
}

class _BotaoNovoPedido extends StatelessWidget {
  final bool habilitado;
  final VoidCallback onPressed;
  const _BotaoNovoPedido({required this.habilitado, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Novo pedido',
      child: Semantics(
        label: 'Novo pedido',
        button: true,
        enabled: habilitado,
        child: Opacity(
          opacity: habilitado ? 1 : .55,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: habilitado ? onPressed : null,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
