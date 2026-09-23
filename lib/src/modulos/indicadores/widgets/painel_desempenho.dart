import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../modelo_indicadores.dart';
import 'graficos_desempenho.dart';

const _petroleo = Color(0xFF103F50);
const _verde = Color(0xFF16877B);
const _azul = Color(0xFF347DB5);
const _roxo = Color(0xFF70579B);

String moedaIndicadores(num centavos) =>
    NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$')
        .format(centavos / 100);

class PainelDesempenho extends StatelessWidget {
  const PainelDesempenho(
      {super.key,
      required this.dados,
      required this.canal,
      required this.onEditarMetas});
  final ModeloIndicadores dados;
  final CanalIndicadores canal;
  final VoidCallback? onEditarMetas;

  @override
  Widget build(BuildContext context) {
    final resumo = dados.resumir(canal);
    final anterior = dados.resumirComparacao(canal);
    final cs = Theme.of(context).colorScheme;
    final pico = resumo.pico;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(children: [
          Icon(
              dados.offline
                  ? Icons.cloud_off_rounded
                  : Icons.cloud_done_outlined,
              size: 16,
              color: dados.offline ? cs.error : _verde),
          const SizedBox(width: 7),
          Expanded(
              child: Text(
                  '${dados.offline ? 'Sem conexão • Última consulta' : 'Atualizado'} ${DateFormat('dd/MM HH:mm').format(dados.atualizadoEm.toLocal())}',
                  style: TextStyle(
                      fontSize: 12,
                      color: dados.offline ? cs.error : cs.onSurfaceVariant))),
        ]),
      ),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_petroleo, Color(0xFF176779)]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: _petroleo.withValues(alpha: .14),
                blurRadius: 24,
                offset: const Offset(0, 8))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(
                    dados.pessoal
                        ? 'MEU DESEMPENHO'
                        : 'DESEMPENHO DO ATENDIMENTO',
                    style: const TextStyle(
                        color: Color(0xFFB4D6DD),
                        fontSize: 10,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700))),
            const SizedBox(width: 8),
            const Icon(Icons.insights_rounded,
                color: Color(0xFF92D5C9), size: 27),
          ]),
          const SizedBox(height: 20),
          const Text('Consumo registrado',
              style: TextStyle(color: Colors.white, fontSize: 14)),
          const SizedBox(height: 6),
          Text(moedaIndicadores(resumo.consumoCentavos),
              style: const TextStyle(
                  fontSize: 34,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white)),
          const SizedBox(height: 16),
          _Comparacao(
              atual: resumo.consumoCentavos,
              anterior: anterior?.consumoCentavos,
              claro: true),
          const SizedBox(height: 16),
          const Text(
              'Inclui contas abertas • não representa o valor recebido no caixa',
              style: TextStyle(
                  color: Color(0xFFC3DFE5), fontSize: 11, height: 1.5)),
        ]),
      ),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final estreito = constraints.maxWidth < 340 ||
            MediaQuery.textScalerOf(context).scale(14) > 20;
        final colunas = estreito ? 1 : (constraints.maxWidth >= 760 ? 4 : 2);
        final largura = (constraints.maxWidth - 12 * (colunas - 1)) / colunas;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          _Numero(
              largura: largura,
              titulo: 'Atendimentos',
              valor: '${resumo.quantidade}',
              legenda: 'Sem cancelamentos',
              icone: Icons.receipt_long_outlined,
              cor: _azul,
              comparacao: _Comparacao(
                  atual: resumo.quantidade, anterior: anterior?.quantidade)),
          _Numero(
              largura: largura,
              titulo: 'Ticket médio',
              valor: moedaIndicadores(resumo.ticketMedioCentavos),
              legenda: 'Consumo por atendimento',
              icone: Icons.account_balance_wallet_outlined,
              cor: _verde,
              comparacao: _Comparacao(
                  atual: resumo.ticketMedioCentavos,
                  anterior: anterior?.ticketMedioCentavos)),
          _Numero(
              largura: largura,
              titulo: 'Finalizados',
              valor: '${resumo.finalizados}',
              legenda: 'Atendimentos concluídos',
              icone: Icons.task_alt_rounded,
              cor: _roxo),
          _Numero(
              largura: largura,
              titulo: 'Cancelados',
              valor: '${resumo.cancelados}',
              legenda:
                  '${NumberFormat('0.#', 'pt_BR').format(resumo.taxaCancelamento)}% das aberturas',
              icone: Icons.cancel_outlined,
              cor: const Color(0xFFB84738)),
        ]);
      }),
      if (anterior != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(
              'Comparação: ${DateFormat('dd/MM').format(anterior.modelo.inicio)} a ${DateFormat('dd/MM').format(anterior.modelo.fim)} (período anterior completo). O período atual pode ainda estar em andamento.',
              style: TextStyle(
                  fontSize: 11, height: 1.45, color: cs.onSurfaceVariant)),
        ),
      const SizedBox(height: 22),
      _Metas(dados: dados, canal: canal, onEditar: onEditarMetas),
      const SizedBox(height: 22),
      GraficosDesempenho(dados: dados, canal: canal),
      const SizedBox(height: 22),
      _Superficie(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _Titulo('Para o seu próximo atendimento',
            Icons.lightbulb_outline_rounded, _roxo),
        const SizedBox(height: 14),
        _Dica(
            icone: Icons.schedule_rounded,
            cor: _azul,
            titulo: pico == null
                ? 'O movimento começa aqui'
                : 'Maior movimento às ${pico.posicao.toString().padLeft(2, '0')}h',
            texto: pico == null
                ? 'Os gráficos serão preenchidos conforme os atendimentos forem registrados.'
                : '${pico.quantidade} atendimento(s) aberto(s) nesse horário no período. Use esse histórico para se preparar para os horários mais movimentados.'),
        if (canal != CanalIndicadores.balcao &&
            (resumo.emAndamento + resumo.emFechamento) > 0) ...[
          const SizedBox(height: 16),
          _Dica(
              icone: Icons.room_service_outlined,
              cor: _verde,
              titulo:
                  '${resumo.emAndamento + resumo.emFechamento} atendimento(s) em aberto',
              texto:
                  '${resumo.emAndamento} em andamento e ${resumo.emFechamento} em fechamento entre os iniciados no período. Confira se os clientes precisam de algo.'),
        ],
        const SizedBox(height: 16),
        const _Dica(
            icone: Icons.restaurant_menu_rounded,
            cor: _roxo,
            titulo: 'Uma sugestão que combina com o pedido',
            texto:
                'Ofereça uma bebida, acompanhamento ou sobremesa quando fizer sentido para o cliente. Acompanhe o resultado pelo ticket médio.'),
      ])),
      const SizedBox(height: 22),
      _Produtos(dados: dados, canal: canal),
      const SizedBox(height: 18),
      _Superficie(
          child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 10),
        leading: Icon(Icons.info_outline_rounded,
            color: cs.onSurfaceVariant, size: 22),
        title: const Text('Como ler os indicadores',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        shape: const Border(),
        collapsedShape: const Border(),
        children: [
          Text(
              'Os dados consideram atendimentos iniciados no período, no dia operacional das 05:00 às 04:59. Contas canceladas não entram no consumo nem no ticket médio. Mesas e comandas são contadas uma única vez.\n\n'
              'O ticket médio é o consumo registrado dividido pelos atendimentos válidos; não é o gasto por pessoa. Metas de consumo e atendimentos são diárias e multiplicadas pelos dias selecionados.\n\n'
              '${dados.pessoal ? dados.criterioPessoal : 'Visão da empresa: reúne os atendimentos registrados por todos os usuários.'}\n\n'
              'Cobertura deste painel: mesas, comandas e balcão. Delivery e recorrentes não compõem estes totais.',
              style: TextStyle(
                  fontSize: 12, height: 1.6, color: cs.onSurfaceVariant))
        ],
      )),
    ]);
  }
}

class _Superficie extends StatelessWidget {
  const _Superficie({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final escuro = Theme.of(context).brightness == Brightness.dark;
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: escuro ? const Color(0xFF202C36) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: escuro
                    ? Colors.white.withValues(alpha: .08)
                    : const Color(0xFFE3EAEE))),
        child: child);
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.texto, this.icone, this.cor);
  final String texto;
  final IconData icone;
  final Color cor;
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
                color: cor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icone,
                color: Theme.of(context).brightness == Brightness.dark
                    ? cor.withValues(red: .6, green: .75, blue: .8)
                    : cor,
                size: 20)),
        const SizedBox(width: 10),
        Expanded(
            child: Text(texto,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700))),
      ]);
}

class _Numero extends StatelessWidget {
  const _Numero(
      {required this.largura,
      required this.titulo,
      required this.valor,
      required this.legenda,
      required this.icone,
      required this.cor,
      this.comparacao});
  final double largura;
  final String titulo, valor, legenda;
  final IconData icone;
  final Color cor;
  final Widget? comparacao;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: largura,
      child: _Superficie(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: cor.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(11)),
            child: Icon(icone,
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFB8D5E2)
                    : cor,
                size: 20)),
        const SizedBox(height: 14),
        Text(titulo,
            style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 5),
        Text(valor,
            style: const TextStyle(
                fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: -.5)),
        const SizedBox(height: 6),
        Text(legenda,
            style: TextStyle(
                fontSize: 10,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
        if (comparacao != null) ...[const SizedBox(height: 10), comparacao!],
      ])));
}

class _Comparacao extends StatelessWidget {
  const _Comparacao(
      {required this.atual, required this.anterior, this.claro = false});
  final num atual;
  final num? anterior;
  final bool claro;
  @override
  Widget build(BuildContext context) {
    final valor = anterior == null
        ? null
        : variacaoPercentualIndicadores(atual, anterior!);
    final positivo = valor != null && valor >= 0;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final cor = claro
        ? const Color(0xFFB4E9DA)
        : valor == null
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : positivo
                ? (escuro ? const Color(0xFF8EE1C2) : const Color(0xFF13745C))
                : (escuro ? const Color(0xFFFFBEAB) : const Color(0xFFA54231));
    final texto = anterior == null
        ? 'Comparação indisponível'
        : valor == null
            ? 'Sem base no período anterior'
            : '${valor > 0 ? '+' : ''}${NumberFormat('0.#', 'pt_BR').format(valor)}% vs. anterior';
    return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (valor != null) ...[
            Icon(
                valor == 0
                    ? Icons.horizontal_rule_rounded
                    : positivo
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                color: cor,
                size: 16),
            const SizedBox(width: 4)
          ],
          Flexible(
              child: Text(texto,
                  style: TextStyle(
                      color: cor, fontSize: 11, fontWeight: FontWeight.w600))),
        ]);
  }
}

class _Metas extends StatelessWidget {
  const _Metas({required this.dados, required this.canal, this.onEditar});
  final ModeloIndicadores dados;
  final CanalIndicadores canal;
  final VoidCallback? onEditar;
  @override
  Widget build(BuildContext context) {
    final metas = dados.metas;
    final resumo = dados.resumir(CanalIndicadores.todos);
    final cs = Theme.of(context).colorScheme;
    final possui = metas != null &&
        (metas.consumoDiarioCentavos > 0 ||
            metas.atendimentosDiarios > 0 ||
            metas.ticketMedioCentavos > 0);
    return _Superficie(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Titulo(dados.pessoal ? 'Minhas metas' : 'Metas do atendimento',
          Icons.flag_outlined, _roxo),
      const SizedBox(height: 8),
      Text('Um objetivo claro para acompanhar sua evolução.',
          style:
              TextStyle(fontSize: 12, height: 1.5, color: cs.onSurfaceVariant)),
      if (possui) ...[
        const SizedBox(height: 20),
        if (metas.consumoDiarioCentavos > 0)
          _Progresso(
              titulo: 'Consumo registrado',
              atual: resumo.consumoCentavos,
              alvo: metas.consumoDiarioCentavos * resumo.diasNoPeriodo,
              dinheiro: true,
              cor: _verde),
        if (metas.atendimentosDiarios > 0)
          _Progresso(
              titulo: 'Atendimentos',
              atual: resumo.quantidade,
              alvo: metas.atendimentosDiarios * resumo.diasNoPeriodo,
              dinheiro: false,
              cor: _azul),
        if (metas.ticketMedioCentavos > 0)
          _Progresso(
              titulo: 'Ticket médio',
              atual: resumo.ticketMedioCentavos,
              alvo: metas.ticketMedioCentavos,
              dinheiro: true,
              cor: _roxo),
        Text(
            'Objetivos para ${resumo.diasNoPeriodo} dia(s) • todos os tipos de atendimento',
            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
      ] else ...[
        const SizedBox(height: 16),
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _roxo.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14)),
            child: Text(
                dados.suporteMetas
                    ? 'Defina metas de consumo diário, quantidade de atendimentos e ticket médio. Aqui você verá o progresso e quanto falta para chegar lá.'
                    : 'Os objetivos estarão disponíveis quando o servidor estiver preparado para salvar suas metas.',
                style: TextStyle(
                    fontSize: 12, height: 1.5, color: cs.onSurfaceVariant))),
      ],
      if (dados.suporteMetas) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(
            onPressed: onEditar,
            icon: const Icon(Icons.tune_rounded, size: 18),
            style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            label: Text(possui ? 'Ajustar metas' : 'Definir metas')),
        if (dados.offline)
          const Text('Conecte-se ao servidor para editar as metas.',
              style: TextStyle(fontSize: 11)),
      ],
    ]));
  }
}

class _Progresso extends StatelessWidget {
  const _Progresso(
      {required this.titulo,
      required this.atual,
      required this.alvo,
      required this.dinheiro,
      required this.cor});
  final String titulo;
  final num atual, alvo;
  final bool dinheiro;
  final Color cor;
  String formato(num v) =>
      dinheiro ? moedaIndicadores(v) : NumberFormat('0', 'pt_BR').format(v);
  @override
  Widget build(BuildContext context) {
    final percentual = atual / alvo;
    final atingiu = atual >= alvo;
    return Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Text(titulo,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13))),
            Text('${NumberFormat('0.#', 'pt_BR').format(percentual * 100)}%',
                style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF9ED8DA)
                        : cor,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                  value: percentual.clamp(0, 1).toDouble(),
                  minHeight: 9,
                  color: cor,
                  backgroundColor: cor.withValues(alpha: .12),
                  semanticsLabel: 'Progresso da meta de $titulo')),
          const SizedBox(height: 8),
          Text('${formato(atual)} de ${formato(alvo)}',
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
              atingiu
                  ? 'Meta alcançada! Continue com um bom atendimento.'
                  : 'Faltam ${formato(alvo - atual)} para a meta.',
              style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ]));
  }
}

class _Dica extends StatelessWidget {
  const _Dica(
      {required this.icone,
      required this.cor,
      required this.titulo,
      required this.texto});
  final IconData icone;
  final Color cor;
  final String titulo, texto;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone,
            size: 19,
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFFAACDDA)
                : cor),
        const SizedBox(width: 10),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(titulo,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(texto,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ])),
      ]);
}

class _Produtos extends StatelessWidget {
  const _Produtos({required this.dados, required this.canal});
  final ModeloIndicadores dados;
  final CanalIndicadores canal;
  @override
  Widget build(BuildContext context) {
    // Um mesmo produto pode vir em mais de um canal; o ranking agrupa antes de ordenar.
    final itens = <String, ({String nome, double quantidade, int centavos})>{};
    for (final p in dados.produtos.where(
        (p) => canal == CanalIndicadores.todos || p.canal == canal.codigo)) {
      final antigo = itens[p.id];
      itens[p.id] = (
        nome: p.nome,
        quantidade: (antigo?.quantidade ?? 0) + p.quantidade,
        centavos: (antigo?.centavos ?? 0) + p.consumoCentavos
      );
    }
    final produtos = itens.values.toList()
      ..sort((a, b) => b.centavos.compareTo(a.centavos));
    final maiores = produtos.take(5).toList();
    final cs = Theme.of(context).colorScheme;
    return _Superficie(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const _Titulo(
          'Produtos em destaque', Icons.restaurant_menu_rounded, _verde),
      const SizedBox(height: 8),
      Text('Os 5 produtos com maior consumo registrado no período.',
          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
      const SizedBox(height: 18),
      if (maiores.isEmpty)
        Text('Ainda não há dados de produtos para esta seleção.',
            style: TextStyle(
                fontSize: 12, height: 1.5, color: cs.onSurfaceVariant)),
      for (var i = 0; i < maiores.length; i++)
        Padding(
            padding: EdgeInsets.only(bottom: i == maiores.length - 1 ? 0 : 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: _verde.withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(9)),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF8EE1C2)
                              : _verde,
                          fontSize: 12,
                          fontWeight: FontWeight.w800))),
              const SizedBox(width: 10),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(maiores[i].nome,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 5),
                    Wrap(spacing: 12, runSpacing: 4, children: [
                      Text(
                          'Qtd.: ${NumberFormat('0.###', 'pt_BR').format(maiores[i].quantidade)}',
                          style: TextStyle(
                              fontSize: 11, color: cs.onSurfaceVariant)),
                      Text(moedaIndicadores(maiores[i].centavos),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700)),
                    ]),
                    const SizedBox(height: 7),
                    ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                            minHeight: 5,
                            value: maiores.first.centavos > 0
                                ? (maiores[i].centavos / maiores.first.centavos)
                                    .clamp(0, 1)
                                : 0,
                            color: _verde,
                            backgroundColor: _verde.withValues(alpha: .08))),
                  ])),
            ])),
    ]));
  }
}
