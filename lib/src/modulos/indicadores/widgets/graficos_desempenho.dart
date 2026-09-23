import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../modelo_indicadores.dart';

const _azul = Color(0xFF347DB5);
const _verde = Color(0xFF16877B);
const _lilas = Color(0xFF70579B);
const _coral = Color(0xFFEF6956);

/// Gráficos da consulta atual. Não retém resultados de consultas anteriores.
class GraficosDesempenho extends StatelessWidget {
  const GraficosDesempenho({
    super.key,
    required this.dados,
    required this.canal,
  });

  final ModeloIndicadores dados;
  final CanalIndicadores canal;

  @override
  Widget build(BuildContext context) {
    final resumo = dados.resumir(canal);
    return LayoutBuilder(builder: (context, constraints) {
      final duasColunas = constraints.maxWidth > 760 &&
          MediaQuery.textScalerOf(context).scale(14) <= 21;
      final largura =
          duasColunas ? (constraints.maxWidth - 24) / 2 : constraints.maxWidth;
      final graficos = <Widget>[
        _MovimentoHorario(resumo: resumo),
        if (diasEntreDatas(dados.inicio, dados.fim) > 0)
          _MovimentoDiario(dados: dados, resumo: resumo),
        _DistribuicaoCanais(dados: dados, canal: canal),
        _SituacaoAtendimentos(resumo: resumo),
      ];
      return Wrap(
        spacing: 24,
        runSpacing: 24,
        children: [
          for (final grafico in graficos)
            SizedBox(width: largura, child: grafico),
        ],
      );
    });
  }
}

class _MovimentoHorario extends StatelessWidget {
  const _MovimentoHorario({required this.resumo});
  final ResumoIndicadores resumo;

  @override
  Widget build(BuildContext context) {
    final porHora = resumo.porHora;
    final pontos = List.generate(24, (index) {
      final hora = (index + horaInicioDiaOperacionalIndicadores) % 24;
      return _PontoGrafico(
        '${hora.toString().padLeft(2, '0')}h',
        porHora[hora].quantidade.toDouble(),
      );
    });
    final maior =
        pontos.fold<double>(0, (valor, p) => math.max(valor, p.valor));
    final picos = pontos.where((p) => p.valor == maior && maior > 0).toList();
    final totalComHora =
        pontos.fold<int>(0, (soma, p) => soma + p.valor.toInt());
    final semHora = resumo.quantidade - totalComHora;
    final cor = _corAdaptada(context, _azul);
    return _CardGrafico(
      titulo: 'Movimento por horário',
      subtitulo: 'Descubra quando o atendimento fica mais intenso.',
      icone: Icons.bar_chart_rounded,
      cor: cor,
      children: [
        if (picos.isNotEmpty) ...[
          _DestaqueGrafico(
            icone: Icons.schedule_rounded,
            cor: cor,
            texto:
                '${picos.first.rotulo} · ${maior.toInt()} ${maior == 1 ? 'atendimento' : 'atendimentos'}${picos.length > 1 ? ' · pico empatado' : ' no pico'}',
          ),
          const SizedBox(height: 16),
          const _LegendaEixo(texto: 'Atendimentos iniciados'),
          const SizedBox(height: 8),
          Semantics(
            label:
                'Atendimentos por horário: ${pontos.where((p) => p.valor > 0).map((p) => '${p.rotulo}, ${p.valor.toInt()}').join('; ')}.',
            excludeSemantics: true,
            child: SizedBox(
              height: 230,
              child: LayoutBuilder(builder: (context, constraints) {
                return SfCartesianChart(
                  margin: const EdgeInsets.only(top: 8, right: 4),
                  plotAreaBorderWidth: 0,
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    header: '',
                    format: 'point.x: point.y atendimentos',
                  ),
                  primaryXAxis: _eixoCategorias(
                    context,
                    intervalo: constraints.maxWidth < 380 ? 4 : 3,
                  ),
                  primaryYAxis: _eixoValores(context, maior),
                  series: <CartesianSeries<_PontoGrafico, String>>[
                    ColumnSeries<_PontoGrafico, String>(
                      name: 'Atendimentos',
                      dataSource: pontos,
                      xValueMapper: (p, _) => p.rotulo,
                      yValueMapper: (p, _) => p.valor,
                      pointColorMapper: (p, _) =>
                          p.valor == maior ? cor : cor.withValues(alpha: 0.28),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                      animationDuration: 0,
                      width: 0.7,
                    ),
                  ],
                );
              }),
            ),
          ),
        ] else
          const _GraficoVazio(
            texto:
                'Os horários aparecem assim que houver atendimentos com hora registrada.',
          ),
        const SizedBox(height: 12),
        _NotaGrafico(
          texto:
              'Dia operacional: 05h às 04h59. Cancelados não entram neste gráfico.${semHora > 0 ? ' $semHora atendimento(s) sem horário informado.' : ''}',
        ),
      ],
    );
  }
}

class _MovimentoDiario extends StatefulWidget {
  const _MovimentoDiario({required this.dados, required this.resumo});
  final ModeloIndicadores dados;
  final ResumoIndicadores resumo;

  @override
  State<_MovimentoDiario> createState() => _MovimentoDiarioState();
}

class _MovimentoDiarioState extends State<_MovimentoDiario> {
  bool consumo = true;

  @override
  Widget build(BuildContext context) {
    final resumo = widget.resumo;
    final inicio = widget.dados.inicio;
    final pontos = resumo.porDia.map((ponto) {
      final dia =
          DateTime(inicio.year, inicio.month, inicio.day + ponto.posicao);
      return _PontoGrafico(
        DateFormat('dd/MM').format(dia),
        consumo ? ponto.consumoCentavos / 100 : ponto.quantidade.toDouble(),
      );
    }).toList();
    final maior =
        pontos.fold<double>(0, (valor, p) => math.max(valor, p.valor));
    final cor = _corAdaptada(context, consumo ? _verde : _azul);
    final temMovimento = pontos.any((p) => p.valor != 0);
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final media = pontos.isEmpty
        ? 0.0
        : pontos.fold<double>(0, (soma, p) => soma + p.valor) / pontos.length;
    return _CardGrafico(
      titulo: 'Movimento por dia',
      subtitulo: 'Acompanhe a evolução no período selecionado.',
      icone: Icons.show_chart_rounded,
      cor: cor,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('Consumo'),
              selected: consumo,
              onSelected: (_) => setState(() => consumo = true),
              selectedColor: cor.withValues(alpha: 0.14),
              side: BorderSide.none,
            ),
            ChoiceChip(
              label: const Text('Atendimentos'),
              selected: !consumo,
              onSelected: (_) => setState(() => consumo = false),
              selectedColor: cor.withValues(alpha: 0.14),
              side: BorderSide.none,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (temMovimento) ...[
          _DestaqueGrafico(
            icone: Icons.insights_rounded,
            cor: cor,
            texto:
                'Média diária: ${consumo ? moeda.format(media) : NumberFormat('0.#', 'pt_BR').format(media)}${consumo ? '' : ' atendimentos'}',
          ),
          const SizedBox(height: 16),
          _LegendaEixo(
            texto:
                consumo ? 'Consumo registrado (R\$)' : 'Atendimentos iniciados',
          ),
          const SizedBox(height: 8),
          Semantics(
            label:
                '${consumo ? 'Consumo' : 'Atendimentos'} por dia: ${pontos.map((p) => '${p.rotulo}, ${consumo ? moeda.format(p.valor) : p.valor.toInt()}').join('; ')}.',
            excludeSemantics: true,
            child: SizedBox(
              height: 230,
              child: SfCartesianChart(
                margin: const EdgeInsets.only(top: 8, right: 8),
                plotAreaBorderWidth: 0,
                tooltipBehavior: TooltipBehavior(
                  enable: true,
                  header: '',
                  builder: (data, point, series, pointIndex, seriesIndex) {
                    final ponto = data as _PontoGrafico;
                    return Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        '${ponto.rotulo}\n${consumo ? moeda.format(ponto.valor) : '${ponto.valor.toInt()} atendimentos'}',
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    );
                  },
                  color: const Color(0xFF103F50),
                ),
                primaryXAxis: _eixoCategorias(
                  context,
                  intervalo: math.max(1, (pontos.length / 5).ceil()).toDouble(),
                ),
                primaryYAxis: _eixoValores(context, maior, dinheiro: consumo),
                series: <CartesianSeries<_PontoGrafico, String>>[
                  AreaSeries<_PontoGrafico, String>(
                    name: consumo ? 'Consumo' : 'Atendimentos',
                    dataSource: pontos,
                    xValueMapper: (p, _) => p.rotulo,
                    yValueMapper: (p, _) => p.valor,
                    borderColor: cor,
                    borderWidth: 3,
                    color: cor.withValues(alpha: 0.13),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        cor.withValues(alpha: 0.26),
                        cor.withValues(alpha: 0.01)
                      ],
                    ),
                    markerSettings: MarkerSettings(
                      isVisible: pontos.length <= 14,
                      width: 6,
                      height: 6,
                      color: _superficie(context),
                      borderColor: cor,
                      borderWidth: 2,
                    ),
                    animationDuration: 0,
                  ),
                ],
              ),
            ),
          ),
        ] else
          const _GraficoVazio(
              texto:
                  'Ainda não há movimento para comparar os dias deste período.'),
        const SizedBox(height: 12),
        _NotaGrafico(
          texto: consumo
              ? 'Inclui contas abertas, sem cancelados. Consumo registrado não é valor recebido no caixa.'
              : 'Contagem pela data de início de cada atendimento, sem cancelados. A média inclui dias sem movimento.',
        ),
      ],
    );
  }
}

class _DistribuicaoCanais extends StatelessWidget {
  const _DistribuicaoCanais({required this.dados, required this.canal});
  final ModeloIndicadores dados;
  final CanalIndicadores canal;

  @override
  Widget build(BuildContext context) {
    final pontos = CanalIndicadores.values
        .where((c) =>
            c != CanalIndicadores.todos &&
            (canal == CanalIndicadores.todos || canal == c))
        .map((c) {
      final resumo = dados.resumir(c);
      final cor = switch (c) {
        CanalIndicadores.mesa => _verde,
        CanalIndicadores.comanda => _lilas,
        _ => _azul,
      };
      return _CanalGrafico(
        c.rotulo,
        resumo.quantidade,
        resumo.consumoCentavos,
        _corAdaptada(context, cor),
      );
    }).toList();
    final total = pontos.fold<int>(0, (soma, p) => soma + p.quantidade);
    final comMovimento = pontos.where((p) => p.quantidade > 0).toList();
    final moeda = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    return _CardGrafico(
      titulo: 'Por tipo de atendimento',
      subtitulo: 'Veja a participação de cada frente de trabalho.',
      icone: Icons.donut_small_rounded,
      cor: _corAdaptada(context, _lilas),
      children: [
        if (comMovimento.length > 1)
          Semantics(
            label:
                'Participação dos tipos de atendimento, $total atendimentos no total.',
            excludeSemantics: true,
            child: SizedBox(
              height: 205,
              child: Stack(alignment: Alignment.center, children: [
                SfCircularChart(
                  margin: EdgeInsets.zero,
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    header: '',
                    format: 'point.x: point.y atendimentos',
                  ),
                  series: <CircularSeries<_CanalGrafico, String>>[
                    DoughnutSeries<_CanalGrafico, String>(
                      dataSource: comMovimento,
                      xValueMapper: (p, _) => p.nome,
                      yValueMapper: (p, _) => p.quantidade,
                      pointColorMapper: (p, _) => p.cor,
                      radius: '92%',
                      innerRadius: '78%',
                      strokeColor: _superficie(context),
                      strokeWidth: 4,
                      startAngle: 270,
                      endAngle: 630,
                      animationDuration: 0,
                    ),
                  ],
                ),
                IgnorePointer(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('$total',
                        style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: _tinta(context))),
                    Text('atendimentos',
                        style: TextStyle(
                            fontSize: 11, color: _textoSecundario(context))),
                  ]),
                ),
              ]),
            ),
          ),
        if (total == 0)
          const _GraficoVazio(
              texto:
                  'A participação aparece quando houver atendimentos neste período.'),
        if (comMovimento.length > 1) const SizedBox(height: 12),
        for (var i = 0; i < pontos.length; i++) ...[
          if (i > 0) const SizedBox(height: 16),
          _BarraResumo(
            nome: pontos[i].nome,
            quantidade: pontos[i].quantidade,
            total: total,
            cor: pontos[i].cor,
            detalhe: moeda.format(pontos[i].centavos / 100),
          ),
        ],
        const SizedBox(height: 18),
        const _NotaGrafico(
            texto:
                'Percentuais por quantidade de atendimentos. Valores mostram consumo registrado, sem cancelados.'),
      ],
    );
  }
}

class _SituacaoAtendimentos extends StatelessWidget {
  const _SituacaoAtendimentos({required this.resumo});
  final ResumoIndicadores resumo;

  @override
  Widget build(BuildContext context) {
    final total = resumo.quantidade + resumo.cancelados;
    final finalizados = resumo.finalizados;
    final outros = resumo.quantidade -
        resumo.emAndamento -
        resumo.emFechamento -
        finalizados;
    final pontos = [
      if (resumo.grupos.any((g) => g.canal != 'Balcao')) ...[
        _CanalGrafico('Em andamento', resumo.emAndamento, 0,
            _corAdaptada(context, _azul)),
        _CanalGrafico('Em fechamento', resumo.emFechamento, 0,
            _corAdaptada(context, _lilas)),
      ],
      _CanalGrafico(
          'Concluídos', finalizados, 0, _corAdaptada(context, _verde)),
      _CanalGrafico(
          'Cancelados', resumo.cancelados, 0, _corAdaptada(context, _coral)),
      if (outros > 0)
        _CanalGrafico('Outras situações', outros, 0, _textoSecundario(context)),
    ];
    return _CardGrafico(
      titulo: 'Situação dos atendimentos',
      subtitulo: 'O que está aberto e o que já foi encerrado.',
      icone: Icons.fact_check_outlined,
      cor: _corAdaptada(context, _verde),
      children: [
        if (total == 0)
          const _GraficoVazio(
              texto: 'Nenhum atendimento no período selecionado.'),
        for (var i = 0; i < pontos.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          _BarraResumo(
            nome: pontos[i].nome,
            quantidade: pontos[i].quantidade,
            total: total,
            cor: pontos[i].cor,
          ),
        ],
        const SizedBox(height: 20),
        const _NotaGrafico(
            texto:
                'Situação atual dos atendimentos iniciados no período. A participação considera também os cancelados.'),
      ],
    );
  }
}

class _CardGrafico extends StatelessWidget {
  const _CardGrafico(
      {required this.titulo,
      required this.subtitulo,
      required this.icone,
      required this.cor,
      required this.children});
  final String titulo;
  final String subtitulo;
  final IconData icone;
  final Color cor;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _superficie(context),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.45)),
          boxShadow: [
            BoxShadow(
                color: const Color(0xFF103F50).withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 6))
          ],
        ),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(13)),
              child: Icon(icone, color: cor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(titulo,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _tinta(context))),
                  const SizedBox(height: 5),
                  Text(subtitulo,
                      style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          color: _textoSecundario(context))),
                ])),
          ]),
          const SizedBox(height: 22),
          ...children,
        ]),
      );
}

class _BarraResumo extends StatelessWidget {
  const _BarraResumo(
      {required this.nome,
      required this.quantidade,
      required this.total,
      required this.cor,
      this.detalhe});
  final String nome;
  final int quantidade;
  final int total;
  final Color cor;
  final String? detalhe;

  @override
  Widget build(BuildContext context) {
    final fracao = total == 0 ? 0.0 : quantidade / total;
    final percentual = NumberFormat('0.#', 'pt_BR').format(fracao * 100);
    return Semantics(
      label:
          '$nome: $quantidade atendimentos, $percentual por cento${detalhe != null ? ', $detalhe de consumo' : ''}.',
      excludeSemantics: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 6, right: 8),
              decoration: BoxDecoration(color: cor, shape: BoxShape.circle)),
          Expanded(
              child: Text(nome,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _tinta(context)))),
          const SizedBox(width: 8),
          Text('$quantidade',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: _tinta(context))),
        ]),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: fracao.clamp(0.0, 1.0),
          minHeight: 7,
          borderRadius: BorderRadius.circular(8),
          color: cor,
          backgroundColor: cor.withValues(alpha: 0.10),
        ),
        const SizedBox(height: 6),
        Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text('$percentual% dos atendimentos',
                  style: TextStyle(
                      fontSize: 11, color: _textoSecundario(context))),
              if (detalhe != null)
                Text(detalhe!,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: cor)),
            ]),
      ]),
    );
  }
}

class _DestaqueGrafico extends StatelessWidget {
  const _DestaqueGrafico(
      {required this.icone, required this.cor, required this.texto});
  final IconData icone;
  final Color cor;
  final String texto;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Icon(icone, color: cor, size: 18),
          const SizedBox(width: 8),
          Expanded(
              child: Text(texto,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700, color: cor))),
        ]),
      );
}

class _LegendaEixo extends StatelessWidget {
  const _LegendaEixo({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) => Text(texto,
      style: TextStyle(
          fontSize: 11,
          color: _textoSecundario(context),
          fontWeight: FontWeight.w600));
}

class _NotaGrafico extends StatelessWidget {
  const _NotaGrafico({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) => Text(texto,
      style: TextStyle(
          fontSize: 11, height: 1.5, color: _textoSecundario(context)));
}

class _GraficoVazio extends StatelessWidget {
  const _GraficoVazio({required this.texto});
  final String texto;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(children: [
          Icon(Icons.insert_chart_outlined_rounded,
              size: 32, color: _textoSecundario(context)),
          const SizedBox(height: 12),
          Text(texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.5, color: _textoSecundario(context))),
        ]),
      );
}

class _PontoGrafico {
  const _PontoGrafico(this.rotulo, this.valor);
  final String rotulo;
  final double valor;
}

class _CanalGrafico {
  const _CanalGrafico(this.nome, this.quantidade, this.centavos, this.cor);
  final String nome;
  final int quantidade;
  final int centavos;
  final Color cor;
}

bool _escuro(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;
Color _superficie(BuildContext context) =>
    _escuro(context) ? const Color(0xFF202C36) : Colors.white;
Color _tinta(BuildContext context) =>
    _escuro(context) ? const Color(0xFFE3F0F4) : const Color(0xFF103F50);
Color _textoSecundario(BuildContext context) =>
    _escuro(context) ? const Color(0xFFB2C2CD) : const Color(0xFF647784);
Color _corAdaptada(BuildContext context, Color cor) =>
    _escuro(context) ? Color.lerp(cor, Colors.white, 0.32)! : cor;

CategoryAxis _eixoCategorias(BuildContext context, {double intervalo = 1}) =>
    CategoryAxis(
      interval: intervalo,
      labelPlacement: LabelPlacement.onTicks,
      labelIntersectAction: AxisLabelIntersectAction.hide,
      labelStyle: TextStyle(fontSize: 10, color: _textoSecundario(context)),
      axisLine: const AxisLine(width: 0),
      majorTickLines: const MajorTickLines(size: 0),
      majorGridLines: const MajorGridLines(width: 0),
    );

NumericAxis _eixoValores(BuildContext context, double maior,
    {bool dinheiro = false}) {
  final intervalo = math.max(1.0, (maior / 4).ceilToDouble());
  return NumericAxis(
    minimum: 0,
    maximum: intervalo * 4,
    interval: intervalo,
    decimalPlaces: 0,
    numberFormat: dinheiro
        ? NumberFormat.compactCurrency(
            locale: 'pt_BR', symbol: 'R\$', decimalDigits: 0)
        : NumberFormat.compact(locale: 'pt_BR'),
    labelStyle: TextStyle(fontSize: 10, color: _textoSecundario(context)),
    axisLine: const AxisLine(width: 0),
    majorTickLines: const MajorTickLines(size: 0),
    majorGridLines: MajorGridLines(
        width: 1,
        dashArray: const [4, 4],
        color: _textoSecundario(context).withValues(alpha: 0.12)),
  );
}
