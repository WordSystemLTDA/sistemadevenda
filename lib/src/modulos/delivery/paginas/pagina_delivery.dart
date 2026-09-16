import 'dart:async';
import 'package:app/src/essencial/api/socket/server.dart';
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
  bool _rotaAberta = false, _ativo = true;
  String? _ocupado;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      final mensagem =
          await executarAcaoDelivery(context, _provedor.servico, atual, acao);
      if (mensagem != null) _mensagem(mensagem);
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
      _mensagem(alvo.impressao == '3'
          ? 'Pedido concluído.'
          : 'Pedido em ${alvo.nome}.');
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
      floatingActionButton: FloatingActionButton.extended(
          onPressed: _ocupado == null
              ? () => _abrir(PaginaNovoDelivery(servico: _provedor.servico))
              : null,
          icon: const Icon(Icons.add),
          label: const Text('Novo pedido')),
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
