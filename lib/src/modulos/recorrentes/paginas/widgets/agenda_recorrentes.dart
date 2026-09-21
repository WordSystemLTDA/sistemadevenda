import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../modelos/modelo_recorrente.dart';
import '../../provedores/provedor_recorrentes.dart';
import 'campos_recorrencia.dart';

const _opcoesHorarioAgenda = [
  _OpcaoHorarioAgenda(
      tipo: 'livre',
      titulo: 'Qualquer horário',
      descricao: 'Sem horário definido',
      icone: Icons.schedule_outlined),
  _OpcaoHorarioAgenda(
      tipo: 'fixo',
      titulo: 'Horário fixo',
      descricao: 'Entrega em horário definido',
      icone: Icons.alarm_outlined),
  _OpcaoHorarioAgenda(
      tipo: 'intervalo',
      titulo: 'Horário da empresa',
      descricao: 'Usa faixa de atendimento',
      icone: Icons.storefront_outlined),
];

const _alturaMinimaCardAgenda = 260.0;

class AgendaRecorrentes extends StatefulWidget {
  final ProvedorRecorrentes provedor;
  final Future<void> Function() novo;
  final Future<void> Function(String id, ModeloRecorrente item) abrirPedido;
  final Future<void> Function(ModeloRecorrente item)? editarItens;
  final Future<void> Function(String id, ModeloRecorrente item)? imprimirPedido;
  final Listenable? atualizacoesAutomaticas;
  final Future<void> Function()? sincronizarAutomaticos;
  final bool exibirAppBar;
  final Widget Function(BuildContext context, String titulo, Widget conteudo,
      VoidCallback? salvar)? formulario;
  final DateTime Function()? agora;
  const AgendaRecorrentes(
      {super.key,
      required this.provedor,
      required this.novo,
      required this.abrirPedido,
      this.editarItens,
      this.imprimirPedido,
      this.atualizacoesAutomaticas,
      this.sincronizarAutomaticos,
      this.exibirAppBar = false,
      this.formulario,
      this.agora});

  @override
  State<AgendaRecorrentes> createState() => _AgendaRecorrentesState();
}

class _AgendaRecorrentesState extends State<AgendaRecorrentes>
    with WidgetsBindingObserver {
  ProvedorRecorrentes get p => widget.provedor;
  Timer? _relogio;
  late DateTime _agora;
  bool _recarregando = false;
  final Set<String> _itensExpandidos = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agora = widget.agora?.call() ?? DateTime.now();
    widget.atualizacoesAutomaticas?.addListener(_aoAtualizacaoAutomatica);
    unawaited(p.listar());
    _relogio =
        Timer.periodic(const Duration(seconds: 1), (_) => _atualizarRelogio());
  }

  @override
  void didUpdateWidget(covariant AgendaRecorrentes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.atualizacoesAutomaticas != widget.atualizacoesAutomaticas) {
      oldWidget.atualizacoesAutomaticas
          ?.removeListener(_aoAtualizacaoAutomatica);
      widget.atualizacoesAutomaticas?.addListener(_aoAtualizacaoAutomatica);
    }
  }

  void _aoAtualizacaoAutomatica() {
    if (!mounted ||
        _recarregando ||
        p.ocupado ||
        p.carregando ||
        ModalRoute.of(context)?.isCurrent == false) {
      return;
    }
    unawaited(p.listar());
  }

  Future<void> _recarregar({bool processarAutomaticos = false}) async {
    if (_recarregando) return;
    _recarregando = true;
    try {
      if (processarAutomaticos) {
        await widget.sincronizarAutomaticos?.call();
      }
      if (mounted) await p.listar();
    } finally {
      _recarregando = false;
    }
  }

  void _atualizarRelogio() {
    if (!mounted || ModalRoute.of(context)?.isCurrent == false) return;
    final anterior = _agora;
    final agora = widget.agora?.call() ?? DateTime.now();
    final tinhaContagem = p.itens
        .any((item) => _estadoAutomatico(item, anterior)?.emContagem == true);
    final temContagem = p.itens
        .any((item) => _estadoAutomatico(item, agora)?.emContagem == true);
    final mudouAtraso = p.itens.any((item) =>
        (_estadoAutomatico(item, anterior)?.atrasado ?? false) !=
        (_estadoAutomatico(item, agora)?.atrasado ?? false));
    _agora = agora;
    if (tinhaContagem || temContagem || mudouAtraso) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !p.carregando && !p.ocupado) {
      unawaited(_recarregar(processarAutomaticos: true));
    }
  }

  @override
  void dispose() {
    _relogio?.cancel();
    widget.atualizacoesAutomaticas?.removeListener(_aoAtualizacaoAutomatica);
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

  Future<void> _verPedido(ModeloRecorrente item) => _acao(() async {
        if (!item.temPedido) {
          throw StateError('Realize o processo antes de abrir o pedido.');
        }
        await widget.abrirPedido(item.idDelivery, item);
        if (mounted) await p.listar();
      });

  Future<void> _imprimirPedido(ModeloRecorrente item) => _acao(() async {
        final imprimir = widget.imprimirPedido;
        if (!item.temPedido || imprimir == null) {
          throw StateError('Realize o processo antes de imprimir o pedido.');
        }
        await imprimir(item.idDelivery, item);
      });

  Future<void> _editarItens(ModeloRecorrente item) => _acao(() async {
        final editar = widget.editarItens;
        if (editar != null) await editar(item);
      });

  Future<void> _processar(ModeloRecorrente item) async {
    var concluido = false;
    await _acao(() async {
      await p.servico.abrir(item);
      concluido = true;
      if (mounted) await p.listar();
    });
    if (mounted && concluido) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(
            const SnackBar(content: Text('Pedido enviado para o Delivery.')));
    }
  }

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

  Future<void> _excluir(ModeloRecorrente item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir recorrência?'),
        content: Text(
          '${item.cliente}\n\nO cliente deixará de receber novos pedidos recorrentes. Os pedidos já enviados ao Delivery serão preservados.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Voltar')),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (!mounted || confirmar != true) return;
    var excluido = false;
    await _acao(() async {
      await p.servico.excluir(item);
      excluido = true;
      if (mounted) await p.listar();
    });
    if (mounted && excluido) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Recorrência excluída.')));
    }
  }

  Future<void> _data() async {
    final dia = await showDatePicker(
        context: context,
        initialDate: p.data,
        firstDate: DateTime(2020),
        lastDate: DateTime(DateTime.now().year + 10));
    if (dia != null && mounted) await p.listar(dia: dia);
  }

  bool _pendenteAutomatico(ModeloRecorrente item) =>
      item.ativo &&
      !item.temPedido &&
      !item.processoCancelado &&
      item.status != 'Pulado' &&
      ['fixo', 'intervalo'].contains(item.configuracao.horarioTipo);

  DateTime? _horarioAutomatico(ModeloRecorrente item) {
    if (!_pendenteAutomatico(item)) return null;
    final partes = item.configuracao.horario.split(':');
    if (partes.length != 2) return null;
    final hora = int.tryParse(partes[0]);
    final minuto = int.tryParse(partes[1]);
    if (hora == null || minuto == null) return null;
    return DateTime(
        item.data.year, item.data.month, item.data.day, hora, minuto);
  }

  _EstadoAutomatico? _estadoAutomatico(ModeloRecorrente item, DateTime agora) {
    final horario = _horarioAutomatico(item);
    if (horario == null) return null;
    return _EstadoAutomatico(horario.difference(agora));
  }

  String _duracao(Duration duracao) {
    final segundos = duracao.inSeconds.clamp(0, 359999);
    final horas = segundos ~/ 3600;
    final minutos = (segundos % 3600) ~/ 60;
    final restante = segundos % 60;
    return '${horas.toString().padLeft(2, '0')}:${minutos.toString().padLeft(2, '0')}:${restante.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: p,
      builder: (context, _) {
        final tema = Theme.of(context);
        final cs = tema.colorScheme;
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
                                          onPressed: () => _recarregar(
                                              processarAutomaticos: true),
                                          child: const Text('Tentar Novamente'))
                                    ])))
                        : p.carregando && p.itens.isEmpty
                            ? const Center(child: CircularProgressIndicator())
                            : itens.isEmpty &&
                                    (p.pesquisa.trim().isNotEmpty ||
                                        p.visao == 'cadastros')
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
                                                  p.pesquisa.trim().isNotEmpty
                                                      ? 'Nenhum resultado encontrado.'
                                                      : 'Nenhum recorrente cadastrado.',
                                                  textAlign: TextAlign.center),
                                              const SizedBox(height: 8),
                                              const Text(
                                                  'Use + para cadastrar um pedido recorrente.',
                                                  textAlign: TextAlign.center)
                                            ])))
                                : RefreshIndicator(
                                    onRefresh: () =>
                                        _recarregar(processarAutomaticos: true),
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
                                              ..._diasDaAgenda(itens),
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
              dia: DateTime(
                  p.data.year, p.data.month, p.data.day - p.diasPeriodo)),
          icon: const Icon(Icons.chevron_left)),
      OutlinedButton.icon(
          onPressed: _data,
          icon: const Icon(Icons.calendar_today_outlined, size: 16),
          label: Text(DateFormat('dd/MM/yyyy').format(p.data))),
      IconButton(
          tooltip: 'Próximo dia',
          onPressed: () => p.listar(
              dia: DateTime(
                  p.data.year, p.data.month, p.data.day + p.diasPeriodo)),
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
        onPressed:
            p.carregando ? null : () => _recarregar(processarAutomaticos: true),
        icon: const Icon(Icons.refresh));
    if (largura < 600) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          IconButton(
              tooltip: 'Dia anterior',
              onPressed: () => p.listar(
                  dia: DateTime(
                      p.data.year, p.data.month, p.data.day - p.diasPeriodo)),
              icon: const Icon(Icons.chevron_left)),
          Expanded(
              child: OutlinedButton.icon(
                  onPressed: _data,
                  icon: const Icon(Icons.calendar_today_outlined, size: 16),
                  label: Text(DateFormat('dd/MM/yyyy').format(p.data)))),
          IconButton(
              tooltip: 'Próximo dia',
              onPressed: () => p.listar(
                  dia: DateTime(
                      p.data.year, p.data.month, p.data.day + p.diasPeriodo)),
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

  List<Widget> _diasDaAgenda(List<ModeloRecorrente> itens) {
    final porDia = <DateTime, List<ModeloRecorrente>>{};
    for (final item in itens) {
      final dia = DateUtils.dateOnly(item.data);
      (porDia[dia] ??= []).add(item);
    }
    final dias = p.pesquisa.trim().isNotEmpty
        ? porDia.keys.toList()
        : {
            for (var indice = 0; indice < p.diasPeriodo; indice++)
              DateTime(p.data.year, p.data.month, p.data.day + indice),
            ...porDia.keys,
          }.toList();
    dias.sort();
    final hoje = DateUtilsRecorrentes.hoje();
    return [
      for (final dia in dias) ...[
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            '${dia == hoje ? 'Hoje · ' : ''}${DateFormat('EEEE, dd/MM', 'pt_BR').format(dia)} · ${porDia[dia]?.length ?? 0} pedido(s)',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
        ),
        _carrosselHorarios(porDia[dia] ?? const []),
      ],
    ];
  }

  Widget _carrosselHorarios(List<ModeloRecorrente> itens) {
    final porTipo = <String, List<ModeloRecorrente>>{
      for (final opcao in _opcoesHorarioAgenda) opcao.tipo: [],
    };
    for (final item in itens) {
      final tipo = porTipo.containsKey(item.configuracao.horarioTipo)
          ? item.configuracao.horarioTipo
          : 'livre';
      porTipo[tipo]!.add(item);
    }
    for (final opcao in _opcoesHorarioAgenda) {
      porTipo[opcao.tipo]!.sort((a, b) {
        if (opcao.tipo != 'livre') {
          final horario =
              a.configuracao.horario.compareTo(b.configuracao.horario);
          if (horario != 0) return horario;
        }
        return a.cliente.toLowerCase().compareTo(b.cliente.toLowerCase());
      });
    }
    return _CarrosselHorariosAgenda(
      faixas: [
        for (final opcao in _opcoesHorarioAgenda)
          _FaixaHorarioAgenda(opcao: opcao, itens: porTipo[opcao.tipo]!),
      ],
      cardBuilder: _card,
    );
  }

  Widget _card(ModeloRecorrente item) {
    final cadastros = p.visao == 'cadastros';
    if (cadastros) return _cardCadastro(item);

    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final futuro = !item.disponivelEm(_agora);
    final pulado = item.status == 'Pulado';
    final indisponivel = item.status == 'Indisponivel';
    final automatico = _estadoAutomatico(item, _agora);
    final preparandoAutomatico = automatico?.emContagem ?? false;
    final automaticoAtrasado = automatico?.atrasado ?? false;
    final podeProcessar = !p.ocupado &&
        item.ativo &&
        !futuro &&
        !pulado &&
        !indisponivel &&
        !item.processoFeito &&
        item.itens.isNotEmpty;
    final situacao = automaticoAtrasado
        ? 'Envio Atrasado'
        : pulado
            ? 'Não entregar'
            : item.statusProcesso == 'Previsto'
                ? 'Aguardando Processo'
                : item.statusProcesso;
    final corSucesso = tema.brightness == Brightness.dark
        ? const Color(0xFF34D399)
        : const Color(0xFF059669);
    final corAlerta = tema.brightness == Brightness.dark
        ? const Color(0xFFFBBF24)
        : const Color(0xFFB45309);
    final corStatus = item.processoCancelado || automaticoAtrasado
        ? cs.error
        : item.processoFeito
            ? corSucesso
            : pulado
                ? corAlerta
                : cs.primary;
    final textoProcesso = futuro
        ? 'Agendado'
        : !item.ativo
            ? 'Recorrência Pausada'
            : pulado
                ? 'Não Entregar'
                : indisponivel
                    ? 'Processo Indisponível'
                    : item.itens.isEmpty
                        ? 'Sem Itens'
                        : item.processoCancelado
                            ? 'Refazer Processo'
                            : item.processoFeito
                                ? 'Processo Feito'
                                : 'Realizar Processo';
    final corFundo = automaticoAtrasado
        ? cs.error
            .withValues(alpha: tema.brightness == Brightness.dark ? 0.14 : 0.06)
        : preparandoAutomatico
            ? corSucesso.withValues(
                alpha: tema.brightness == Brightness.dark ? 0.14 : 0.07)
            : cs.surface;
    final corBorda = automaticoAtrasado
        ? cs.error.withValues(alpha: 0.45)
        : preparandoAutomatico
            ? corSucesso.withValues(alpha: 0.45)
            : cs.outlineVariant;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _alturaMinimaCardAgenda),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: corFundo,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: corBorda)),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Flexible(
                    child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: corStatus.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(situacao,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.labelSmall?.copyWith(
                                color: corStatus,
                                fontWeight: FontWeight.w700)))),
                if (item.numeroPedido.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text('#${item.numeroPedido}',
                      style: tema.textTheme.labelMedium
                          ?.copyWith(color: cs.onSurfaceVariant)),
                ],
                const Spacer(),
                _menuCard(item, futuro),
              ]),
              const SizedBox(height: 6),
              Text(item.cliente,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tema.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 16, runSpacing: 8, children: [
                _detalhe(
                    item.tipoEntrega == '2'
                        ? Icons.shopping_bag_outlined
                        : Icons.delivery_dining_outlined,
                    item.entregaTexto),
                _detalhe(Icons.schedule, item.configuracao.horarioTexto),
              ]),
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
              if (preparandoAutomatico || automaticoAtrasado) ...[
                const SizedBox(height: 7),
                Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                    decoration: BoxDecoration(
                        color: (automaticoAtrasado ? cs.error : corSucesso)
                            .withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(4)),
                    child: Row(children: [
                      Icon(
                          automaticoAtrasado
                              ? Icons.warning_amber_rounded
                              : Icons.timer_outlined,
                          size: 16,
                          color: automaticoAtrasado ? cs.error : corSucesso),
                      const SizedBox(width: 6),
                      Expanded(
                          child: Text(
                              automaticoAtrasado
                                  ? 'Envio automático não realizado'
                                  : 'Envio automático em ${automatico == null ? '00:00:00' : _duracao(automatico.restante)}',
                              style: tema.textTheme.labelMedium?.copyWith(
                                  color: automaticoAtrasado
                                      ? cs.error
                                      : corSucesso,
                                  fontWeight: FontWeight.w700)))
                    ])),
              ],
              const Divider(height: 18),
              _secaoItens(item, corSucesso),
              if (item.observacao.isNotEmpty)
                Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(item.observacao,
                        style: Theme.of(context).textTheme.bodySmall)),
              const SizedBox(height: 8),
              Row(children: [
                Tooltip(
                    message: 'Imprimir Pedido',
                    child: SizedBox(
                        width: 42,
                        height: 34,
                        child: OutlinedButton(
                            onPressed: !p.ocupado &&
                                    item.temPedido &&
                                    widget.imprimirPedido != null
                                ? () => _imprimirPedido(item)
                                : null,
                            style: _estiloBotaoCard(),
                            child: const Icon(Icons.print_rounded, size: 16)))),
                const SizedBox(width: 6),
                Tooltip(
                    message: 'Ver o Pedido',
                    child: SizedBox(
                        width: 52,
                        height: 34,
                        child: OutlinedButton(
                            onPressed: !p.ocupado && item.temPedido
                                ? () => _verPedido(item)
                                : null,
                            style: _estiloBotaoCard(),
                            child: const FittedBox(child: Text('Ver'))))),
                const SizedBox(width: 6),
                Expanded(
                    child: SizedBox(
                        height: 34,
                        child: FilledButton(
                            onPressed:
                                podeProcessar ? () => _processar(item) : null,
                            style: FilledButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: const Size(0, 34),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5))),
                            child: FittedBox(
                                child: Text(textoProcesso,
                                    style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700))))))
              ]),
            ])),
      ),
    );
  }

  Widget _secaoItens(ModeloRecorrente item, Color corSucesso) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    final expandido = _itensExpandidos.contains(item.chave);
    final possuiItens = item.itens.isNotEmpty;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
              color: Colors.transparent,
              child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: possuiItens
                      ? () => setState(() {
                            if (expandido) {
                              _itensExpandidos.remove(item.chave);
                            } else {
                              _itensExpandidos.add(item.chave);
                            }
                          })
                      : null,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(children: [
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                                color: corSucesso.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(3)),
                            child: Text('Itens',
                                style: tema.textTheme.labelSmall?.copyWith(
                                    color: corSucesso,
                                    fontWeight: FontWeight.w700))),
                        const SizedBox(width: 6),
                        Expanded(
                            child: Text(
                                '${item.itens.length} ${item.itens.length == 1 ? 'item' : 'itens'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tema.textTheme.bodySmall)),
                        if (possuiItens) ...[
                          Flexible(
                              child: Text(
                                  expandido ? 'Ocultar itens' : 'Ver itens',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tema.textTheme.labelMedium?.copyWith(
                                      color: cs.primary,
                                      fontWeight: FontWeight.w600))),
                          const SizedBox(width: 2),
                          Icon(
                              expandido
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              size: 18,
                              color: cs.primary),
                        ]
                      ])))),
          if (!possuiItens)
            Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text('Adicione produtos ao pedido base.',
                    style:
                        tema.textTheme.bodySmall?.copyWith(color: cs.error))),
          if (expandido)
            Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var indice = 0;
                          indice < item.itens.length;
                          indice++) ...[
                        if (indice > 0)
                          Divider(height: 12, color: cs.outlineVariant),
                        Text(item.itens[indice].texto,
                            style: tema.textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        for (final detalhe in item.itens[indice].detalhes)
                          Padding(
                              padding: const EdgeInsets.only(left: 12, top: 3),
                              child: Text('• $detalhe',
                                  style: tema.textTheme.bodySmall
                                      ?.copyWith(color: cs.onSurfaceVariant))),
                      ]
                    ])),
        ]);
  }

  Widget _cardCadastro(ModeloRecorrente item) {
    final tema = Theme.of(context);
    final cs = tema.colorScheme;
    return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: cs.outlineVariant)),
        child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                        child: Text(item.cliente,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tema.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700))),
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                            color: (item.ativo ? cs.primary : cs.error)
                                .withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(item.ativo ? 'Ativo' : 'Pausado',
                            style: tema.textTheme.labelSmall?.copyWith(
                                color: item.ativo ? cs.primary : cs.error,
                                fontWeight: FontWeight.w700)))
                  ]),
                  const SizedBox(height: 8),
                  _detalhe(
                      Icons.event_repeat_rounded, item.configuracao.diasTexto),
                  const SizedBox(height: 5),
                  _detalhe(
                      Icons.schedule_outlined, item.configuracao.horarioTexto),
                  const SizedBox(height: 5),
                  _detalhe(Icons.account_balance_wallet_outlined,
                      item.configuracao.pagamentoTexto),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: OutlinedButton.icon(
                            onPressed: p.ocupado ? null : () => _editar(item),
                            icon: const Icon(Icons.edit_calendar_outlined,
                                size: 16),
                            label: const Text('Editar'))),
                    const SizedBox(width: 8),
                    Expanded(
                        child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                                foregroundColor: cs.error),
                            onPressed: p.ocupado ? null : () => _excluir(item),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 16),
                            label: const Text('Excluir')))
                  ])
                ])));
  }

  ButtonStyle _estiloBotaoCard() => OutlinedButton.styleFrom(
      padding: EdgeInsets.zero,
      minimumSize: const Size(0, 34),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)));

  Widget _menuCard(ModeloRecorrente item, bool futuro) => SizedBox.square(
      dimension: 30,
      child: PopupMenuButton<String>(
          tooltip: 'Opções do recorrente',
          padding: EdgeInsets.zero,
          iconSize: 18,
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (opcao) {
            if (opcao == 'editar') unawaited(_editar(item));
            if (opcao == 'editar_itens' && widget.editarItens != null) {
              unawaited(_editarItens(item));
            }
            if (opcao == 'excluir') unawaited(_excluir(item));
            if (opcao == 'pular') unawaited(_pular(item));
            if (opcao == 'retomar') {
              unawaited(_acao(() async {
                await p.servico.restaurar(item);
                if (mounted) await p.listar();
              }));
            }
          },
          itemBuilder: (context) => [
                if (widget.editarItens != null)
                  const PopupMenuItem(
                      value: 'editar_itens',
                      child: ListTile(
                          leading: Icon(Icons.edit_note_outlined),
                          title: Text('Editar Itens e Ingredientes'),
                          contentPadding: EdgeInsets.zero)),
                const PopupMenuItem(
                    value: 'editar',
                    child: ListTile(
                        leading: Icon(Icons.edit_calendar_outlined),
                        title: Text('Editar Recorrência'),
                        contentPadding: EdgeInsets.zero)),
                if (!item.temPedido && item.status == 'Previsto' && !futuro)
                  const PopupMenuItem(
                      value: 'pular',
                      child: ListTile(
                          leading: Icon(Icons.event_busy_outlined),
                          title: Text('Pular Dia'),
                          contentPadding: EdgeInsets.zero)),
                if (item.status == 'Pulado')
                  const PopupMenuItem(
                      value: 'retomar',
                      child: ListTile(
                          leading: Icon(Icons.restore_rounded),
                          title: Text('Retomar Dia'),
                          contentPadding: EdgeInsets.zero)),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'excluir',
                    child: ListTile(
                        leading: Icon(Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.error),
                        title: Text('Excluir Recorrência',
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                        contentPadding: EdgeInsets.zero)),
              ]));

  Widget _detalhe(IconData icone, String texto) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone,
            size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(child: Text(texto))
      ]);
}

class _OpcaoHorarioAgenda {
  final String tipo;
  final String titulo;
  final String descricao;
  final IconData icone;
  const _OpcaoHorarioAgenda(
      {required this.tipo,
      required this.titulo,
      required this.descricao,
      required this.icone});
}

class _EstadoAutomatico {
  static const antecedencia = Duration(minutes: 30);
  final Duration restante;
  const _EstadoAutomatico(this.restante);
  bool get emContagem => restante > Duration.zero && restante <= antecedencia;
  bool get atrasado => restante <= Duration.zero;
}

class _FaixaHorarioAgenda {
  final _OpcaoHorarioAgenda opcao;
  final List<ModeloRecorrente> itens;
  const _FaixaHorarioAgenda({required this.opcao, required this.itens});
}

class _CarrosselHorariosAgenda extends StatefulWidget {
  final List<_FaixaHorarioAgenda> faixas;
  final Widget Function(ModeloRecorrente item) cardBuilder;
  const _CarrosselHorariosAgenda(
      {required this.faixas, required this.cardBuilder});

  @override
  State<_CarrosselHorariosAgenda> createState() =>
      _CarrosselHorariosAgendaState();
}

class _CarrosselHorariosAgendaState extends State<_CarrosselHorariosAgenda> {
  late final ScrollController _rolagem = ScrollController()
    ..addListener(_atualizarLimites);
  bool _noInicio = true;
  bool _noFim = false;

  @override
  void didUpdateWidget(covariant _CarrosselHorariosAgenda oldWidget) {
    super.didUpdateWidget(oldWidget);
    _agendarAtualizacaoLimites();
  }

  @override
  void dispose() {
    _rolagem
      ..removeListener(_atualizarLimites)
      ..dispose();
    super.dispose();
  }

  void _agendarAtualizacaoLimites() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _atualizarLimites());
  }

  void _atualizarLimites() {
    if (!mounted || !_rolagem.hasClients) return;
    final posicao = _rolagem.position;
    final noInicio = posicao.pixels <= posicao.minScrollExtent + 1;
    final noFim = posicao.maxScrollExtent <= posicao.minScrollExtent ||
        posicao.pixels >= posicao.maxScrollExtent - 1;
    if (noInicio == _noInicio && noFim == _noFim) return;
    setState(() {
      _noInicio = noInicio;
      _noFim = noFim;
    });
  }

  void _mover(int direcao) {
    if (!_rolagem.hasClients) return;
    final posicao = _rolagem.position;
    final destino =
        (_rolagem.offset + (posicao.viewportDimension * 0.88 * direcao))
            .clamp(posicao.minScrollExtent, posicao.maxScrollExtent)
            .toDouble();
    _rolagem.animateTo(destino,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final larguraDisponivel = constraints.maxWidth;
        final double larguraFaixa = larguraDisponivel >= 1080
            ? (larguraDisponivel - 24) / 3
            : larguraDisponivel >= 600
                ? math.min(440.0, larguraDisponivel * 0.72)
                : math.max(240.0, larguraDisponivel * 0.9);
        final larguraConteudo = larguraFaixa * widget.faixas.length +
            12 * (widget.faixas.length - 1);
        final rolavel = larguraConteudo > larguraDisponivel + 1;
        _agendarAtualizacaoLimites();
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (rolavel)
                Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Expanded(
                          child: Text('Deslize para ver os horários',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant))),
                      IconButton(
                          tooltip: 'Horário anterior',
                          onPressed: _noInicio ? null : () => _mover(-1),
                          icon: const Icon(Icons.chevron_left_rounded),
                          visualDensity: VisualDensity.compact),
                      IconButton(
                          tooltip: 'Próximo horário',
                          onPressed: _noFim ? null : () => _mover(1),
                          icon: const Icon(Icons.chevron_right_rounded),
                          visualDensity: VisualDensity.compact),
                    ])),
              SingleChildScrollView(
                  controller: _rolagem,
                  scrollDirection: Axis.horizontal,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var indice = 0;
                            indice < widget.faixas.length;
                            indice++) ...[
                          SizedBox(
                              width: larguraFaixa,
                              child: _ColunaHorarioAgenda(
                                  faixa: widget.faixas[indice],
                                  cardBuilder: widget.cardBuilder)),
                          if (indice < widget.faixas.length - 1)
                            const SizedBox(width: 12),
                        ]
                      ])),
            ]);
      });
}

class _ColunaHorarioAgenda extends StatelessWidget {
  final _FaixaHorarioAgenda faixa;
  final Widget Function(ModeloRecorrente item) cardBuilder;
  const _ColunaHorarioAgenda({required this.faixa, required this.cardBuilder});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Container(
        key: ValueKey('faixa-horario-${faixa.opcao.tipo}'),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            color: cores.surfaceContainerHighest.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: cores.outlineVariant)),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          ColoredBox(
              color: cores.surface,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                            color: cores.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(6)),
                        child: Icon(faixa.opcao.icone,
                            size: 18, color: cores.primary)),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(faixa.opcao.titulo,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          const SizedBox(height: 2),
                          Text(faixa.opcao.descricao,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tema.textTheme.bodySmall
                                  ?.copyWith(color: cores.onSurfaceVariant)),
                        ])),
                    const SizedBox(width: 8),
                    Container(
                        constraints: const BoxConstraints(minWidth: 28),
                        height: 24,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                            color:
                                cores.primaryContainer.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(12)),
                        child: Text('${faixa.itens.length}',
                            style: tema.textTheme.labelMedium?.copyWith(
                                color: cores.primary,
                                fontWeight: FontWeight.w700)))
                  ]))),
          Divider(height: 1, color: cores.outlineVariant),
          Padding(
              padding: const EdgeInsets.all(12),
              child: faixa.itens.isEmpty
                  ? ConstrainedBox(
                      constraints: const BoxConstraints(
                          minHeight: _alturaMinimaCardAgenda),
                      child: Center(
                          child: Text('Nenhum pedido neste horário.',
                              textAlign: TextAlign.center,
                              style: tema.textTheme.bodySmall
                                  ?.copyWith(color: cores.onSurfaceVariant))))
                  : Column(children: [
                      for (var indice = 0;
                          indice < faixa.itens.length;
                          indice++) ...[
                        cardBuilder(faixa.itens[indice]),
                        if (indice < faixa.itens.length - 1)
                          const SizedBox(height: 12),
                      ]
                    ]))
        ]));
  }
}
