import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../modelos/modelo_recorrente.dart';
import '../../provedores/provedor_recorrentes.dart';
import 'campos_recorrencia.dart';

class AgendaRecorrentes extends StatefulWidget {
  final ProvedorRecorrentes provedor;
  final Future<void> Function() novo;
  final Future<void> Function(String id, ModeloRecorrente item) abrirPedido;
  final Future<void> Function(String id, ModeloRecorrente item)?
      confirmarPedido;
  final bool exibirAppBar;
  final Widget Function(BuildContext context, String titulo, Widget conteudo,
      VoidCallback? salvar)? formulario;
  const AgendaRecorrentes(
      {super.key,
      required this.provedor,
      required this.novo,
      required this.abrirPedido,
      this.confirmarPedido,
      this.exibirAppBar = false,
      this.formulario});

  @override
  State<AgendaRecorrentes> createState() => _AgendaRecorrentesState();
}

class _AgendaRecorrentesState extends State<AgendaRecorrentes>
    with WidgetsBindingObserver {
  ProvedorRecorrentes get p => widget.provedor;
  Timer? _timer;
  DateTime _ultimoHoje = DateUtilsRecorrentes.hoje();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(p.listar());
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => _atualizar());
  }

  void _atualizar() {
    if (p.ocupado ||
        p.carregando ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    final hoje = DateUtilsRecorrentes.hoje();
    final acompanharHoje = p.data == _ultimoHoje;
    _ultimoHoje = hoje;
    unawaited(p.listar(dia: acompanharHoje ? hoje : null));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _atualizar();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _acao(Future<void> Function() acao) async {
    try {
      await p.executar(acao);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is StateError
                ? e.message.toString()
                : 'Não foi possível concluir. Tente novamente.')));
      }
    }
  }

  Future<void> _abrir(ModeloRecorrente item, {bool confirmar = false}) =>
      _acao(() async {
        final id = await p.servico.abrir(item);
        if (!mounted) return;
        await (confirmar && widget.confirmarPedido != null
            ? widget.confirmarPedido!(id, item)
            : widget.abrirPedido(id, item));
        if (mounted) await p.listar();
      });

  Future<void> _editar(ModeloRecorrente item) async {
    var configuracao = item.configuracao;
    var ativo = item.ativo;
    Widget editor(BuildContext context) =>
        StatefulBuilder(builder: (context, setState) {
          final conteudo = Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CamposRecorrencia(
                    valor: configuracao,
                    onChanged: (valor) => setState(() => configuracao = valor)),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recorrência ativa'),
                    subtitle: const Text(
                        'Pause quando o cliente não precisar receber.'),
                    value: ativo,
                    onChanged: (valor) => setState(() => ativo = valor)),
              ]);
          final VoidCallback? salvar = configuracao.erro == null
              ? () => Navigator.pop(context, true)
              : null;
          if (widget.formulario != null) {
            return widget.formulario!(context, item.cliente, conteudo, salvar);
          }
          if (MediaQuery.sizeOf(context).width < 600) {
            return Scaffold(
              appBar: AppBar(title: const Text('Editar Recorrência')),
              body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(item.cliente,
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        conteudo
                      ])),
              bottomNavigationBar: SafeArea(
                  minimum: const EdgeInsets.all(12),
                  child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 12,
                      children: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Fechar')),
                        FilledButton(
                            onPressed: salvar, child: const Text('Salvar'))
                      ])),
            );
          }
          return AlertDialog(
              title: Text(item.cliente),
              scrollable: true,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              content: SizedBox(width: 560, child: conteudo),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Fechar')),
                FilledButton(onPressed: salvar, child: const Text('Salvar'))
              ]);
        });
    final salvar = MediaQuery.sizeOf(context).width < 600
        ? await Navigator.push<bool>(
            context, MaterialPageRoute(builder: editor))
        : await showDialog<bool>(context: context, builder: editor);
    if (!mounted || salvar != true) return;
    await _acao(() async {
      await p.servico.editar(item, configuracao, ativo);
      if (mounted) await p.listar();
    });
  }

  Future<void> _pular(ModeloRecorrente item) async {
    final sim = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Não entregar neste dia?'),
              content: Text(
                  '${item.cliente}\n${DateFormat('dd/MM/yyyy').format(item.data)}\n\nOs próximos dias continuam agendados.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Voltar')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Pular Dia'))
              ],
            ));
    if (!mounted || sim != true) return;
    await _acao(() async {
      await p.servico.pular(item);
      if (mounted) await p.listar();
    });
  }

  Future<void> _data() async {
    final dia = await showDatePicker(
        context: context,
        initialDate: p.data,
        firstDate: DateTime(2020),
        lastDate: DateTime(DateTime.now().year + 10));
    if (dia != null && mounted) await p.listar(dia: dia);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final cs = Theme.of(context).colorScheme;
        final itens = p.filtrados;
        return Scaffold(
          appBar: widget.exibirAppBar
              ? AppBar(title: const Text('Recorrentes'))
              : null,
          floatingActionButton: FloatingActionButton(
              tooltip: 'Novo Recorrente',
              onPressed: p.ocupado
                  ? null
                  : () => _acao(() async {
                        await widget.novo();
                        if (mounted) await p.listar();
                      }),
              child: const Icon(Icons.add)),
          body: SafeArea(
              top: false,
              child: Column(children: [
                Padding(
                    padding: const EdgeInsets.all(12),
                    child: LayoutBuilder(
                        builder: (context, constraints) =>
                            _cabecalho(constraints.maxWidth))),
                if (p.carregando || p.ocupado)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                    child: p.erro != null
                        ? Center(
                            child: SingleChildScrollView(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.cloud_off_outlined,
                                          color: cs.error),
                                      const SizedBox(height: 12),
                                      Text(p.erro!,
                                          textAlign: TextAlign.center),
                                      const SizedBox(height: 12),
                                      OutlinedButton(
                                          onPressed: () => p.listar(),
                                          child: const Text('Tentar Novamente'))
                                    ])))
                        : p.carregando && p.itens.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : itens.isEmpty
                                ? Center(
                                    child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(24),
                                        child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.event_repeat_outlined,
                                                  size: 40,
                                                  color: cs.onSurfaceVariant),
                                              const SizedBox(height: 16),
                                              Text(
                                                  p.pesquisa.isNotEmpty
                                                      ? 'Nenhum resultado encontrado.'
                                                      : p.visao == 'cadastros'
                                                          ? 'Nenhum recorrente cadastrado.'
                                                          : 'Nenhum pedido previsto neste período.',
                                                  textAlign: TextAlign.center),
                                              const SizedBox(height: 8),
                                              const Text(
                                                  'Use + para cadastrar um pedido recorrente.',
                                                  textAlign: TextAlign.center)
                                            ])))
                                : RefreshIndicator(
                                    onRefresh: () => p.listar(),
                                    child: LayoutBuilder(
                                        builder: (context, constraints) {
                                      final escala =
                                          MediaQuery.textScalerOf(context)
                                                  .scale(14) /
                                              14;
                                      final colunas = math.max(
                                          1,
                                          ((constraints.maxWidth - 24) /
                                                  (360 * escala))
                                              .floor());
                                      final largura = (constraints.maxWidth -
                                              24 -
                                              (colunas - 1) * 12) /
                                          colunas;
                                      return ListView(
                                          padding: const EdgeInsets.fromLTRB(
                                              12, 4, 12, 88),
                                          physics:
                                              const AlwaysScrollableScrollPhysics(),
                                          children: [
                                            Padding(
                                                padding: const EdgeInsets.only(
                                                    bottom: 8),
                                                child: Text(
                                                    '${itens.length} ${p.visao == 'cadastros' ? 'recorrente(s)' : 'pedido(s) previsto(s)'}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall)),
                                            if (p.visao == 'cadastros')
                                              Wrap(
                                                  spacing: 12,
                                                  runSpacing: 12,
                                                  children: [
                                                    for (final item in itens)
                                                      SizedBox(
                                                          width: largura,
                                                          child: _card(item))
                                                  ]),
                                            if (p.visao != 'cadastros')
                                              for (final dia in {
                                                for (final item in itens)
                                                  item.data,
                                              }.toList()
                                                ..sort()) ...[
                                                Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(vertical: 12),
                                                  child: Text(
                                                    DateUtils.isSameDay(
                                                            dia, DateTime.now())
                                                        ? 'Hoje · ${DateFormat('dd/MM').format(dia)}'
                                                        : DateFormat(
                                                                'EEEE, dd/MM',
                                                                'pt_BR')
                                                            .format(dia),
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleSmall
                                                        ?.copyWith(
                                                            color: cs.primary),
                                                  ),
                                                ),
                                                Wrap(
                                                    spacing: 12,
                                                    runSpacing: 12,
                                                    children: [
                                                      for (final item in itens
                                                          .where((item) =>
                                                              item.data == dia))
                                                        SizedBox(
                                                            width: largura,
                                                            child: _card(item)),
                                                    ]),
                                              ],
                                          ]);
                                    }))),
              ])),
        );
      });

  Widget _cabecalho(double largura) {
    final data = Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      IconButton(
          tooltip: 'Dia anterior',
          onPressed: () => p.listar(
              dia: p.data.subtract(Duration(
                  days: p.visao == 'mes'
                      ? 30
                      : p.visao == 'semana'
                          ? 7
                          : 1))),
          icon: const Icon(Icons.chevron_left)),
      OutlinedButton.icon(
          onPressed: _data,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(DateFormat('dd/MM/yyyy').format(p.data))),
      IconButton(
          tooltip: 'Próximo dia',
          onPressed: () => p.listar(
              dia: p.data.add(Duration(
                  days: p.visao == 'mes'
                      ? 30
                      : p.visao == 'semana'
                          ? 7
                          : 1))),
          icon: const Icon(Icons.chevron_right)),
      TextButton(
          onPressed: () =>
              p.listar(dia: DateUtilsRecorrentes.hoje(), modo: 'dia'),
          child: const Text('Hoje')),
    ]);
    final modos = Wrap(spacing: 4, children: [
      for (final modo in const [
        ('dia', 'Dia'),
        ('semana', '7 dias'),
        ('mes', '30 dias'),
        ('cadastros', 'Cadastros')
      ])
        ChoiceChip(
            label: Text(modo.$2),
            selected: p.visao == modo.$1,
            onSelected: (_) => p.listar(modo: modo.$1))
    ]);
    final busca = SizedBox(
        width: math.min(largura, 300),
        child: TextField(
            onChanged: p.pesquisar,
            decoration: const InputDecoration(
                isDense: true,
                hintText: 'Pesquisar cliente ou produto',
                prefixIcon: Icon(Icons.search, size: 18),
                border: OutlineInputBorder())));
    final atualizar = IconButton(
        tooltip: 'Atualizar',
        onPressed: p.carregando ? null : () => p.listar(),
        icon: const Icon(Icons.refresh));
    if (largura < 600) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
              tooltip: 'Dia anterior',
              onPressed: () => p.listar(
                  dia: p.data.subtract(Duration(
                      days: p.visao == 'mes'
                          ? 30
                          : p.visao == 'semana'
                              ? 7
                              : 1))),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _data,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(DateFormat('dd/MM/yyyy').format(p.data)))),
          IconButton(
              tooltip: 'Próximo dia',
              onPressed: () => p.listar(
                  dia: p.data.add(Duration(
                      days: p.visao == 'mes'
                          ? 30
                          : p.visao == 'semana'
                              ? 7
                              : 1))),
              icon: const Icon(Icons.chevron_right)),
        ]),
        const SizedBox(height: 4),
        SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              TextButton(
                  onPressed: () =>
                      p.listar(dia: DateUtilsRecorrentes.hoje(), modo: 'dia'),
                  child: const Text('Hoje')),
              modos,
            ])),
        const SizedBox(height: 8),
        Row(children: [Expanded(child: busca), atualizar]),
      ]);
    }
    if (largura >= 1080 && MediaQuery.textScalerOf(context).scale(14) <= 16) {
      return Row(children: [
        data,
        const SizedBox(width: 12),
        modos,
        const Spacer(),
        busca,
        atualizar
      ]);
    }
    return SizedBox(
        width: largura,
        child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [data, modos, busca, atualizar]));
  }

  Widget _card(ModeloRecorrente item) {
    final cs = Theme.of(context).colorScheme;
    final cadastros = p.visao == 'cadastros';
    final futuro = !item.disponivelEm(DateTime.now());
    final podeAbrir = !p.ocupado &&
        item.status != 'Pulado' &&
        item.status != 'Indisponivel' &&
        (item.temPedido || (item.ativo && !futuro && item.itens.isNotEmpty));
    final situacao = cadastros
        ? (item.ativo ? 'Ativo' : 'Pausado')
        : item.status == 'Pulado'
            ? 'Não entregar'
            : item.status == 'Previsto'
                ? 'Previsto'
                : item.pago
                    ? (item.pagamento.mensal || item.pagamento.forma == 2
                        ? 'Em conta'
                        : 'Pago')
                    : item.status;
    return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: cs.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                    child: Text(item.cliente,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600))),
                const SizedBox(width: 8),
                Tooltip(
                    message: 'Editar recorrência',
                    child: IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: p.ocupado ? null : () => _editar(item),
                        icon:
                            const Icon(Icons.edit_calendar_outlined, size: 20)))
              ]),
              Wrap(spacing: 8, runSpacing: 4, children: [
                Text(
                    cadastros
                        ? item.configuracao.diasTexto
                        : DateFormat('EEE, dd/MM', 'pt_BR').format(item.data),
                    style: TextStyle(
                        color: cs.primary, fontWeight: FontWeight.w600)),
                Text(situacao, style: TextStyle(color: cs.onSurfaceVariant)),
                if (item.numeroPedido.isNotEmpty && !cadastros)
                  Text('#${item.numeroPedido}'),
              ]),
              const SizedBox(height: 12),
              Wrap(spacing: 16, runSpacing: 8, children: [
                _detalhe(
                    item.tipoEntrega == '2'
                        ? Icons.shopping_bag_outlined
                        : Icons.delivery_dining_outlined,
                    item.entregaTexto),
                _detalhe(Icons.schedule, item.configuracao.horarioTexto),
              ]),
              if (!cadastros)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(item.configuracao.diasTexto,
                        style: Theme.of(context).textTheme.bodySmall)),
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child:
                      _detalhe(Icons.payments_outlined, item.pagamento.resumo)),
              if (item.pagamento.mensal && item.pagamento.vencimento != null)
                Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                        'Vence em ${DateFormat('dd/MM/yyyy').format(item.pagamento.vencimento!)}',
                        style: Theme.of(context).textTheme.bodySmall)),
              if (item.endereco.isNotEmpty && item.tipoEntrega == '1')
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(item.endereco,
                        style: Theme.of(context).textTheme.bodySmall)),
              const Divider(height: 24),
              if (item.itens.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
                            .format(item.total),
                        style: Theme.of(context).textTheme.titleMedium)),
              if (item.itens.isEmpty)
                const Text('Adicione os produtos ao primeiro pedido.')
              else ...[
                for (final produto in item.itens.take(3))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(produto.texto)),
                if (item.itens.length > 3)
                  ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text('Mais ${item.itens.length - 3} item(ns)'),
                      children: [
                        for (final produto in item.itens.skip(3))
                          Align(
                              alignment: Alignment.centerLeft,
                              child: Text(produto.texto))
                      ]),
              ],
              if (item.observacao.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(item.observacao,
                        style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(height: 12),
              if (cadastros)
                OutlinedButton.icon(
                    onPressed: p.ocupado ? null : () => _editar(item),
                    icon: const Icon(Icons.event_repeat, size: 18),
                    label: const Text('Editar Agenda'))
              else
                Wrap(spacing: 8, runSpacing: 4, children: [
                  FilledButton.icon(
                      onPressed: podeAbrir
                          ? () => _abrir(item,
                              confirmar:
                                  !item.encerrado && item.itens.isNotEmpty)
                          : null,
                      icon: Icon(
                          item.encerrado
                              ? Icons.receipt_long_outlined
                              : Icons.arrow_forward,
                          size: 18),
                      label: Text(widget.confirmarPedido != null &&
                              !item.encerrado &&
                              item.itens.isNotEmpty &&
                              !futuro
                          ? 'Confirmar Pedido'
                          : item.temPedido
                              ? (item.encerrado
                                  ? 'Ver Pedido'
                                  : 'Continuar Pedido')
                              : futuro
                                  ? 'Agendado'
                                  : 'Revisar e Finalizar')),
                  if (widget.confirmarPedido != null &&
                      !item.encerrado &&
                      podeAbrir &&
                      item.itens.isNotEmpty)
                    TextButton(
                        onPressed: () => _abrir(item),
                        child: const Text('Alterar Pedido')),
                  if (!item.temPedido && item.status == 'Previsto' && !futuro)
                    TextButton(
                        onPressed: p.ocupado ? null : () => _pular(item),
                        child: const Text('Pular Dia')),
                  if (item.status == 'Pulado')
                    TextButton(
                        onPressed: p.ocupado
                            ? null
                            : () => _acao(() async {
                                  await p.servico.restaurar(item);
                                  if (mounted) await p.listar();
                                }),
                        child: const Text('Retomar Dia')),
                ]),
            ])));
  }

  Widget _detalhe(IconData icone, String texto) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(child: Text(texto))
      ]);
}
