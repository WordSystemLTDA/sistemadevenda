import 'dart:async';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import 'modelo_indicadores.dart';
import 'servico_indicadores.dart';

class PaginaIndicadores extends StatefulWidget {
  const PaginaIndicadores({super.key, this.servico});
  final ServicoIndicadores? servico;
  @override
  State<PaginaIndicadores> createState() => _PaginaIndicadoresState();
}

class _PaginaIndicadoresState extends State<PaginaIndicadores>
    with WidgetsBindingObserver {
  late final ServicoIndicadores servico;
  late DateTime inicio;
  late DateTime fim;
  int periodo = 1;
  CanalIndicadores canal = CanalIndicadores.todos;
  ModeloIndicadores? dados;
  String? erro;
  bool carregando = false;
  bool ativo = true;
  int consulta = 0;
  CancelToken? cancelamento;
  Timer? timer;

  @override
  void initState() {
    super.initState();
    servico = widget.servico ??
        ServicoIndicadores(
            Modular.get<DioCliente>(), Modular.get<UsuarioProvedor>());
    _definirPeriodoSelecionado(1);
    WidgetsBinding.instance.addObserver(this);
    servico.usuarios.addListener(_trocarUsuario);
    _carregar();
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (ativo &&
          !carregando &&
          (ModalRoute.of(context)?.isCurrent ?? false)) {
        _carregar();
      }
    });
  }

  void _definirPeriodoSelecionado(int valor) {
    final hojeOperacional = dataOperacionalIndicadores(DateTime.now());
    if (valor == -1) {
      fim = DateTime(
          hojeOperacional.year, hojeOperacional.month, hojeOperacional.day - 1);
      inicio = fim;
    } else {
      fim = hojeOperacional;
      inicio = DateTime(fim.year, fim.month, fim.day - valor + 1);
    }
    periodo = valor;
  }

  void _trocarUsuario() {
    cancelamento?.cancel();
    consulta++;
    setState(() {
      dados = null;
      erro = null;
      carregando = false;
    });
    _carregar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ativo = state == AppLifecycleState.resumed;
    if (ativo) {
      _carregar();
    } else {
      cancelamento?.cancel();
      consulta++;
      if (mounted) setState(() => carregando = false);
    }
  }

  Future<void> _carregar() async {
    if (!mounted || !ativo) return;
    cancelamento?.cancel();
    cancelamento = CancelToken();
    final atual = ++consulta;
    if (periodo != 0) _definirPeriodoSelecionado(periodo);
    setState(() {
      carregando = true;
      erro = null;
      if (dados?.inicio != inicio || dados?.fim != fim) dados = null;
    });
    try {
      final resultado =
          await servico.consultar(inicio, fim, cancelToken: cancelamento);
      if (mounted && atual == consulta) setState(() => dados = resultado);
    } catch (falha) {
      if (mounted && atual == consulta) {
        setState(() {
          dados = null;
          erro = falha is FalhaIndicadores
              ? falha.mensagem
              : 'Não foi possível consultar os indicadores.';
        });
      }
    } finally {
      if (mounted && atual == consulta) setState(() => carregando = false);
    }
  }

  Future<void> _escolherDatas() async {
    final intervalo = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
        initialDateRange: DateTimeRange(start: inicio, end: fim),
        helpText: 'Período dos atendimentos',
        builder: (context, child) => Localizations.override(
              context: context,
              locale: const Locale('pt', 'BR'),
              delegates: GlobalMaterialLocalizations.delegates,
              child: Theme(
                data: Theme.of(context).copyWith(
                    datePickerTheme: Theme.of(context).datePickerTheme.copyWith(
                          rangePickerHeaderHeadlineStyle:
                              const TextStyle(fontSize: 18),
                        )),
                child: child!,
              ),
            ),
        saveText: 'Aplicar');
    if (intervalo == null || !mounted) return;
    if (diasEntreDatas(intervalo.start, intervalo.end) >= 90) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selecione até 90 dias.')));
      return;
    }
    setState(() {
      periodo = 0;
      inicio = intervalo.start;
      fim = intervalo.end;
      dados = null;
    });
    await _carregar();
  }

  @override
  void dispose() {
    consulta++;
    cancelamento?.cancel();
    timer?.cancel();
    servico.usuarios.removeListener(_trocarUsuario);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
          title: const Text('Indicadores'),
          backgroundColor: cs.inversePrimary,
          actions: [
            IconButton(
                tooltip: 'Atualizar indicadores',
                onPressed: carregando ? null : _carregar,
                icon: const Icon(Icons.refresh))
          ]),
      body: SafeArea(
          top: false,
          child: RefreshIndicator(
              onRefresh: _carregar,
              child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(children: [
                                  Expanded(
                                      child: InputDecorator(
                                          decoration: const InputDecoration(
                                              labelText: 'Período',
                                              border: OutlineInputBorder()),
                                          child: DropdownButtonHideUnderline(
                                              child: DropdownButton<int>(
                                                  value: periodo,
                                                  isExpanded: true,
                                                  isDense: true,
                                                  items: const [
                                                    DropdownMenuItem(
                                                        value: 1,
                                                        child: Text('Hoje')),
                                                    DropdownMenuItem(
                                                        value: -1,
                                                        child: Text('Ontem')),
                                                    DropdownMenuItem(
                                                        value: 7,
                                                        child: Text(
                                                            'Últimos 7 dias')),
                                                    DropdownMenuItem(
                                                        value: 30,
                                                        child: Text(
                                                            'Últimos 30 dias')),
                                                    DropdownMenuItem(
                                                        value: 0,
                                                        child: Text(
                                                            'Personalizado'))
                                                  ],
                                                  onChanged: (valor) {
                                                    if (valor == null) return;
                                                    if (valor == 0) {
                                                      _escolherDatas();
                                                      return;
                                                    }
                                                    setState(() {
                                                      _definirPeriodoSelecionado(
                                                          valor);
                                                      dados = null;
                                                    });
                                                    _carregar();
                                                  })))),
                                  IconButton(
                                      tooltip: 'Selecionar datas',
                                      onPressed: _escolherDatas,
                                      icon: const Icon(
                                          Icons.date_range_outlined)),
                                ]),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<CanalIndicadores>(
                                    initialValue: canal,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                        labelText: 'Atendimento',
                                        border: OutlineInputBorder()),
                                    items: CanalIndicadores.values
                                        .map((c) => DropdownMenuItem(
                                            value: c, child: Text(c.rotulo)))
                                        .toList(),
                                    onChanged: (valor) {
                                      if (valor != null) {
                                        setState(() => canal = valor);
                                      }
                                    }),
                                const SizedBox(height: 12),
                                Text(
                                    '${DateFormat('dd/MM/yyyy').format(inicio)} a ${DateFormat('dd/MM/yyyy').format(fim)}',
                                    style:
                                        TextStyle(color: cs.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text('Dia operacional: 05:00 às 04:59',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: cs.onSurfaceVariant)),
                                SizedBox(
                                    height: 12,
                                    child: carregando
                                        ? const Center(
                                            child: LinearProgressIndicator(
                                                minHeight: 2))
                                        : null),
                                if (erro != null)
                                  Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 24),
                                      child: Column(children: [
                                        Icon(Icons.cloud_off_outlined,
                                            color: cs.onSurfaceVariant,
                                            size: 32),
                                        const SizedBox(height: 12),
                                        Text(erro!,
                                            textAlign: TextAlign.center),
                                        const SizedBox(height: 12),
                                        OutlinedButton.icon(
                                            onPressed: _carregar,
                                            icon: const Icon(Icons.refresh),
                                            label:
                                                const Text('Tentar novamente')),
                                      ])),
                                if (dados != null)
                                  _ConteudoIndicadores(
                                      dados: dados!, canal: canal),
                              ],
                            ))),
                  ]))),
    );
  }
}

class _ConteudoIndicadores extends StatelessWidget {
  const _ConteudoIndicadores({required this.dados, required this.canal});
  final ModeloIndicadores dados;
  final CanalIndicadores canal;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final resumo = dados.resumir(canal);
    final pico = resumo.pico;
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final azul = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF85B7ED)
        : const Color(0xFF2869A8);
    final verde = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF77CEB7)
        : const Color(0xFF16755C);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(
            dados.offline
                ? Icons.cloud_off_outlined
                : Icons.cloud_done_outlined,
            size: 18,
            color: dados.offline ? cs.error : verde),
        const SizedBox(width: 8),
        Expanded(
            child: Text(
                '${dados.offline ? 'Sem conexão • Última consulta' : 'Atualizado'} ${DateFormat('dd/MM HH:mm').format(dados.atualizadoEm.toLocal())}',
                style: TextStyle(
                    color: dados.offline ? cs.error : cs.onSurfaceVariant))),
      ]),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, tamanho) {
        final colunas = tamanho.maxWidth >= 720
            ? 3
            : tamanho.maxWidth >= 340 &&
                    MediaQuery.textScalerOf(context).scale(14) <= 20
                ? 2
                : 1;
        final largura = (tamanho.maxWidth - 12 * (colunas - 1)) / colunas;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _Metrica(
              largura: largura,
              nome: 'Atendimentos',
              valor: '${resumo.quantidade}',
              icone: Icons.receipt_long_outlined,
              cor: azul),
          _Metrica(
              largura: largura,
              nome: 'Consumo registrado',
              valor: moeda.format(resumo.consumoCentavos / 100),
              icone: Icons.account_balance_wallet_outlined,
              cor: verde,
              detalhe:
                  'Consumo dos atendimentos iniciados no período, sem cancelados. Inclui contas abertas; não é valor recebido no caixa.'),
          _Metrica(
              largura: largura,
              nome: 'Horário de pico',
              valor: pico == null
                  ? 'Sem movimento'
                  : '${pico.posicao.toString().padLeft(2, '0')}h • ${pico.quantidade}',
              icone: Icons.schedule,
              cor: azul,
              detalhe:
                  'Aberturas por hora, sem cancelamentos. Em empate, mostra o primeiro horário. Horário local do servidor.'),
          _Metrica(
              largura: largura,
              nome: 'Cancelados',
              valor: '${resumo.cancelados}',
              icone: Icons.cancel_outlined,
              cor: cs.error),
          if (canal != CanalIndicadores.balcao) ...[
            _Metrica(
                largura: largura,
                nome: 'Em andamento',
                valor: '${resumo.emAndamento}',
                icone: Icons.table_restaurant_outlined,
                cor: verde,
                detalhe:
                    'Mesas e comandas iniciadas no período e ainda em andamento.'),
            _Metrica(
                largura: largura,
                nome: 'Em fechamento',
                valor: '${resumo.emFechamento}',
                icone: Icons.point_of_sale_outlined,
                cor: cs.onSurfaceVariant,
                detalhe:
                    'Mesas e comandas iniciadas no período e atualmente em fechamento.'),
          ],
        ]);
      }),
      if (resumo.quantidade == 0)
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Nenhum atendimento válido neste período.',
                textAlign: TextAlign.center)),
      _Grafico(
          titulo: 'Movimento por horário',
          pontos: resumo.porHora,
          cor: azul,
          porHora: true,
          inicio: dados.inicio),
      if (dados.inicio != dados.fim)
        _Grafico(
            titulo: 'Movimento por dia',
            pontos: resumo.porDia,
            cor: verde,
            porHora: false,
            inicio: dados.inicio),
      const Divider(height: 32),
      Text('Por atendimento', style: Theme.of(context).textTheme.titleMedium),
      for (final c in CanalIndicadores.values.where((c) =>
          c != CanalIndicadores.todos &&
          (canal == CanalIndicadores.todos || c == canal)))
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(children: [
              Expanded(child: Text(c.rotulo)),
              Text('${dados.resumir(c).quantidade}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              Flexible(
                  child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                          moeda.format(dados.resumir(c).consumoCentavos / 100),
                          textAlign: TextAlign.end))),
            ])),
    ]);
  }
}

class _Metrica extends StatelessWidget {
  const _Metrica(
      {required this.largura,
      required this.nome,
      required this.valor,
      required this.icone,
      required this.cor,
      this.detalhe});
  final double largura;
  final String nome;
  final String valor;
  final IconData icone;
  final Color cor;
  final String? detalhe;
  @override
  Widget build(BuildContext context) => Container(
      width: largura,
      padding: const EdgeInsets.all(12),
      constraints: const BoxConstraints(minHeight: 124),
      decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          border:
              Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            height: 44,
            child: Row(children: [
              Icon(icone, size: 20, color: cor),
              const Spacer(),
              if (detalhe != null)
                Tooltip(
                    message: detalhe!,
                    triggerMode: TooltipTriggerMode.tap,
                    child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.info_outline, size: 18)))
            ])),
        const SizedBox(height: 4),
        Text(nome, style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Text(valor,
            style: TextStyle(
                fontSize: 22, color: cor, fontWeight: FontWeight.w600)),
      ]));
}

class _Grafico extends StatelessWidget {
  const _Grafico(
      {required this.titulo,
      required this.pontos,
      required this.cor,
      required this.porHora,
      required this.inicio});
  final String titulo;
  final List<PontoIndicadores> pontos;
  final Color cor;
  final bool porHora;
  final DateTime inicio;
  String rotulo(int posicao) => porHora
      ? '${posicao.toString().padLeft(2, '0')}h'
      : DateFormat('dd/MM')
          .format(DateTime(inicio.year, inicio.month, inicio.day + posicao));
  double get intervalo {
    final maximo = pontos.fold<int>(
        0, (maior, p) => p.quantidade > maior ? p.quantidade : maior);
    return maximo == 0 ? 1 : (maximo / 4).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titulo, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        SizedBox(
            height: 230,
            child: SfCartesianChart(
              plotAreaBorderWidth: 0,
              tooltipBehavior: TooltipBehavior(
                  enable: true, header: '', format: 'point.x: point.y'),
              primaryXAxis: CategoryAxis(
                  majorGridLines: const MajorGridLines(width: 0),
                  labelIntersectAction: AxisLabelIntersectAction.hide),
              primaryYAxis: NumericAxis(
                  minimum: 0,
                  maximum: intervalo * 4,
                  interval: intervalo,
                  decimalPlaces: 0,
                  axisLine: const AxisLine(width: 0)),
              series: <CartesianSeries<PontoIndicadores, String>>[
                ColumnSeries<PontoIndicadores, String>(
                    dataSource: pontos,
                    xValueMapper: (ponto, _) => rotulo(ponto.posicao),
                    yValueMapper: (ponto, _) => ponto.quantidade,
                    color: cor,
                    animationDuration: 0,
                    width: 0.7),
              ],
            )),
      ]));
}
