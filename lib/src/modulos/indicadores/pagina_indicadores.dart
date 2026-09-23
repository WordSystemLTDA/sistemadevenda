import 'dart:async';

import 'package:app/src/essencial/api/dio_cliente.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'widgets/painel_desempenho.dart';
import 'widgets/editor_metas_indicadores.dart';

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
  String escopo = 'empresa';
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
      final resultado = await servico.consultar(inicio, fim,
          cancelToken: cancelamento, escopo: escopo);
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

  Future<void> _editarMetas() async {
    final atuais = dados;
    if (atuais == null || !atuais.suporteMetas || atuais.offline) return;
    final salvo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => EditorMetasIndicadores(
        servico: servico,
        escopo: escopo,
        metas: atuais.metas ?? const MetasIndicadores(),
      ),
    );
    if (salvo == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Metas salvas. Vamos acompanhar sua evolução!')));
      await _carregar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final escuro = theme.brightness == Brightness.dark;
    final tinta = escuro ? const Color(0xFFB7DCE6) : const Color(0xFF103F50);
    return Scaffold(
      backgroundColor:
          escuro ? const Color(0xFF15212A) : const Color(0xFFF3F7F9),
      appBar: AppBar(
        title: const Text('Indicadores',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor:
            escuro ? const Color(0xFF15212A) : const Color(0xFFF3F7F9),
        foregroundColor: tinta,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
              tooltip: 'Atualizar indicadores',
              onPressed: carregando ? null : _carregar,
              icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: _carregar,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1160),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Cada atendimento conta.',
                            style: TextStyle(
                                fontSize: 26,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.6,
                                color: tinta)),
                        const SizedBox(height: 8),
                        Text(
                            'Acompanhe seus resultados e dê o próximo passo nas suas metas.',
                            style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: cs.onSurfaceVariant)),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                              color: escuro
                                  ? const Color(0xFF202C36)
                                  : const Color(0xFFE7EEF2),
                              borderRadius: BorderRadius.circular(14)),
                          padding: const EdgeInsets.all(4),
                          child: LayoutBuilder(builder: (context, limites) {
                            final empilhar = limites.maxWidth < 320 ||
                                MediaQuery.textScalerOf(context).scale(14) > 20;
                            final botoes = [
                              _botaoEscopo('empresa', 'Visão da empresa',
                                  Icons.storefront_outlined),
                              _botaoEscopo('pessoal', 'Meus atendimentos',
                                  Icons.person_outline_rounded),
                            ];
                            return empilhar
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: botoes)
                                : Row(
                                    children: botoes
                                        .map((b) => Expanded(child: b))
                                        .toList());
                          }),
                        ),
                        Padding(
                            padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                            child: Text(
                                escopo == 'pessoal'
                                    ? 'Atendimentos registrados pelo seu usuário.'
                                    : 'Mesas, comandas e balcão de toda a empresa.',
                                style: TextStyle(
                                    fontSize: 11, color: cs.onSurfaceVariant))),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                              color: escuro
                                  ? const Color(0xFF202C36)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color:
                                      cs.outlineVariant.withValues(alpha: .5))),
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LayoutBuilder(builder: (context, limites) {
                                  final filtros = [
                                    Row(children: [
                                      Expanded(
                                          child: InputDecorator(
                                              decoration: _decoracao(
                                                  'Período',
                                                  Icons
                                                      .calendar_today_outlined),
                                              child:
                                                  DropdownButtonHideUnderline(
                                                      child:
                                                          DropdownButton<int>(
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
                                                          'Personalizado')),
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
                                                },
                                              )))),
                                      IconButton(
                                          tooltip: 'Selecionar datas',
                                          onPressed: _escolherDatas,
                                          icon: const Icon(
                                              Icons.date_range_outlined)),
                                    ]),
                                    DropdownButtonFormField<CanalIndicadores>(
                                      initialValue: canal,
                                      isExpanded: true,
                                      decoration: _decoracao('Atendimento',
                                          Icons.room_service_outlined),
                                      items: CanalIndicadores.values
                                          .map((c) => DropdownMenuItem(
                                              value: c, child: Text(c.rotulo)))
                                          .toList(),
                                      onChanged: (valor) {
                                        if (valor != null) {
                                          setState(() => canal = valor);
                                        }
                                      },
                                    ),
                                  ];
                                  return limites.maxWidth > 620
                                      ? Row(children: [
                                          Expanded(child: filtros[0]),
                                          const SizedBox(width: 16),
                                          Expanded(child: filtros[1])
                                        ])
                                      : Column(children: [
                                          filtros[0],
                                          const SizedBox(height: 12),
                                          filtros[1]
                                        ]);
                                }),
                                const SizedBox(height: 12),
                                Text(
                                    '${DateFormat('dd/MM/yyyy').format(inicio)} a ${DateFormat('dd/MM/yyyy').format(fim)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: cs.onSurfaceVariant)),
                                const SizedBox(height: 4),
                                Text('Dia operacional: 05:00 às 04:59',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant)),
                              ]),
                        ),
                        SizedBox(
                            height: 20,
                            child: carregando
                                ? const Center(
                                    child:
                                        LinearProgressIndicator(minHeight: 2))
                                : null),
                        if (erro != null)
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: cs.errorContainer.withValues(alpha: .35),
                                borderRadius: BorderRadius.circular(20)),
                            child: Column(children: [
                              Icon(Icons.cloud_off_outlined,
                                  color: cs.onSurfaceVariant, size: 32),
                              const SizedBox(height: 12),
                              Text(erro!, textAlign: TextAlign.center),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                  onPressed: _carregar,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Tentar novamente')),
                            ]),
                          ),
                        if (dados != null)
                          PainelDesempenho(
                              dados: dados!,
                              canal: canal,
                              onEditarMetas:
                                  dados!.offline ? null : _editarMetas),
                        if (carregando && dados == null)
                          const Padding(
                              padding: EdgeInsets.symmetric(vertical: 48),
                              child: Column(children: [
                                Icon(Icons.insights_rounded,
                                    size: 40, color: Color(0xFF347DB5)),
                                SizedBox(height: 12),
                                Text('Preparando seu desempenho...',
                                    textAlign: TextAlign.center),
                              ])),
                      ]),
                )),
              ],
            ),
          )),
    );
  }

  InputDecoration _decoracao(String rotulo, IconData icone) => InputDecoration(
        labelText: rotulo,
        labelStyle: const TextStyle(fontSize: 13),
        prefixIcon: Icon(icone, size: 18),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
      );

  Widget _botaoEscopo(String valor, String texto, IconData icone) {
    final selecionado = escopo == valor;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: selecionado
          ? (escuro ? const Color(0xFF354C5B) : Colors.white)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: () {
          if (escopo == valor) return;
          setState(() {
            escopo = valor;
            dados = null;
          });
          _carregar();
        },
        child: Semantics(
          selected: selecionado,
          button: true,
          child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child:
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(icone,
                    size: 18,
                    color: selecionado
                        ? (escuro
                            ? const Color(0xFFB7DCE6)
                            : const Color(0xFF103F50))
                        : Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Flexible(
                    child: Text(texto,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: selecionado
                                ? FontWeight.w700
                                : FontWeight.w500))),
              ])),
        ),
      ),
    );
  }
}
