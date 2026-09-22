import 'package:flutter/material.dart';
import '../../modelos/modelo_recorrente.dart';

class CamposRecorrencia extends StatelessWidget {
  final ConfiguracaoRecorrencia valor;
  final ValueChanged<ConfiguracaoRecorrencia> onChanged;
  final bool primeiroPedido;
  final bool exibirErro;
  final DateTime Function()? relogio;
  final bool permitirEnderecos;
  final bool somenteEnderecos;
  final String enderecoPadraoId;
  final List<EnderecoRecorrente> enderecos;
  const CamposRecorrencia(
      {super.key,
      required this.valor,
      required this.onChanged,
      this.primeiroPedido = false,
      this.exibirErro = true,
      this.relogio,
      this.permitirEnderecos = false,
      this.somenteEnderecos = false,
      this.enderecoPadraoId = '',
      this.enderecos = const []});

  String get _primeiroEndereco =>
      enderecos
          .where((endereco) => endereco.id == enderecoPadraoId)
          .firstOrNull
          ?.id ??
      enderecos.firstOrNull?.id ??
      '';

  void _atualizarDias(List<int> dias) {
    final enderecosAtualizados = {...valor.enderecosPorDia};
    if (valor.enderecoModo == 'por_dia') {
      for (final dia in dias) {
        enderecosAtualizados.putIfAbsent(dia, () => _primeiroEndereco);
      }
    }
    onChanged(valor.copyWith(
        dias: dias..sort(), enderecosPorDia: enderecosAtualizados));
  }

  void _alterarModoEndereco(String modo) {
    final enderecosAtualizados = {...valor.enderecosPorDia};
    if (modo == 'por_dia') {
      for (final dia in valor.dias) {
        enderecosAtualizados.putIfAbsent(dia, () => _primeiroEndereco);
      }
    }
    onChanged(valor.copyWith(
        enderecoModo: modo, enderecosPorDia: enderecosAtualizados));
  }

  Future<void> _hora(BuildContext context, bool fim) async {
    final partes = (fim ? valor.horarioFim : valor.horario).split(':');
    final hora = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: int.parse(partes[0]), minute: int.parse(partes[1])),
        initialEntryMode: TimePickerEntryMode.input);
    if (hora == null) return;
    final texto =
        '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}';
    onChanged(fim
        ? valor.copyWith(horarioFim: texto)
        : valor.copyWith(horario: texto));
  }

  Widget _gradeJustificada(
    BuildContext context, {
    required List<Widget> botoes,
    required double larguraMinima,
    double espacamento = 8,
  }) {
    final larguraTela = MediaQuery.sizeOf(context).width;
    final larguraDisponivel = larguraTela - (larguraTela >= 600 ? 96 : 32);
    final escalaTexto = MediaQuery.textScalerOf(context).scale(14) / 14;
    final larguraPorBotao = larguraMinima * escalaTexto.clamp(1, 1.5);
    final porLinha =
        ((larguraDisponivel + espacamento) / (larguraPorBotao + espacamento))
            .floor()
            .clamp(1, botoes.length);
    final linhas = <Widget>[];

    for (var inicio = 0; inicio < botoes.length; inicio += porLinha) {
      final fim = (inicio + porLinha).clamp(0, botoes.length);
      final linha = botoes.sublist(inicio, fim);
      linhas.add(Row(children: [
        for (var indice = 0; indice < linha.length; indice++) ...[
          Expanded(
              child: SizedBox(width: double.infinity, child: linha[indice])),
          if (indice < linha.length - 1) SizedBox(width: espacamento),
        ],
      ]));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var indice = 0; indice < linhas.length; indice++) ...[
          linhas[indice],
          if (indice < linhas.length - 1) SizedBox(height: espacamento),
        ],
      ],
    );
  }

  Widget _titulo(BuildContext context, String texto, IconData icone) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icone, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
        ]),
      );

  Widget _cartaoOpcao(
    BuildContext context, {
    required String chave,
    required String texto,
    required IconData icone,
    required bool selecionado,
    required VoidCallback onTap,
    double altura = 86,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selecionado,
      label: texto,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: AnimatedContainer(
            key: ValueKey(chave),
            duration: const Duration(milliseconds: 150),
            height: altura,
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 7),
            decoration: BoxDecoration(
              color: selecionado
                  ? cs.primaryContainer.withValues(alpha: .55)
                  : cs.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selecionado ? cs.primary : cs.outlineVariant,
                width: selecionado ? 1.5 : 1,
              ),
            ),
            child: Stack(children: [
              Align(
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selecionado
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        icone,
                        size: 20,
                        color: selecionado ? cs.onPrimary : cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          texto,
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: selecionado ? cs.primary : cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (selecionado)
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(Icons.check_circle, size: 18, color: cs.primary),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _enderecosEntrega(BuildContext context) {
    final padrao = enderecos
            .where((endereco) => endereco.id == enderecoPadraoId)
            .firstOrNull ??
        enderecos.firstOrNull;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (!somenteEnderecos) const SizedBox(height: 20),
      _titulo(context, 'Endereço de entrega', Icons.location_on_outlined),
      _gradeJustificada(
        context,
        larguraMinima: 140,
        botoes: [
          _cartaoOpcao(
            context,
            chave: 'recorrencia-endereco-padrao',
            texto: 'Mesmo endereço',
            icone: Icons.home_outlined,
            selecionado: valor.enderecoModo == 'padrao',
            onTap: () => _alterarModoEndereco('padrao'),
          ),
          _cartaoOpcao(
            context,
            chave: 'recorrencia-endereco-por-dia',
            texto: 'Escolher por dia',
            icone: Icons.edit_calendar_outlined,
            selecionado: valor.enderecoModo == 'por_dia',
            onTap: () => _alterarModoEndereco('por_dia'),
          ),
        ],
      ),
      const SizedBox(height: 8),
      Text(
        valor.enderecoModo == 'padrao'
            ? 'Todas as entregas: ${padrao?.titulo ?? 'endereço principal'}'
            : 'Escolha onde entregar em cada dia da semana.',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      if (valor.enderecoModo == 'por_dia') ...[
        const SizedBox(height: 12),
        if (enderecos.isEmpty)
          Text(
              'Cadastre um endereço para o cliente antes de programar as entregas.',
              style: TextStyle(color: Theme.of(context).colorScheme.error))
        else
          for (final dia in [...valor.dias]..sort()) ...[
            DropdownButtonFormField<String>(
              key: ValueKey(
                  'endereco-recorrente-$dia-${valor.enderecosPorDia[dia]}'),
              initialValue: enderecos.any(
                      (endereco) => endereco.id == valor.enderecosPorDia[dia])
                  ? valor.enderecosPorDia[dia]
                  : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: ConfiguracaoRecorrencia.nomesDias[dia - 1],
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                for (final endereco in enderecos)
                  DropdownMenuItem(
                      value: endereco.id,
                      child: Text(endereco.titulo,
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (endereco) {
                if (endereco == null) return;
                onChanged(valor.copyWith(enderecosPorDia: {
                  ...valor.enderecosPorDia,
                  dia: endereco
                }));
              },
            ),
            if (enderecos
                    .where(
                        (endereco) => endereco.id == valor.enderecosPorDia[dia])
                    .firstOrNull
                    ?.detalhe
                    .isNotEmpty ??
                false)
              Padding(
                padding: const EdgeInsets.fromLTRB(48, 4, 8, 0),
                child: Text(
                    enderecos
                        .firstWhere((endereco) =>
                            endereco.id == valor.enderecosPorDia[dia])
                        .detalhe,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
            const SizedBox(height: 8),
          ],
        Text(
            'O pedido usará automaticamente o endereço programado para a data.',
            style: Theme.of(context).textTheme.bodySmall),
      ],
      if (exibirErro && valor.erroEnderecoEntrega != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(valor.erroEnderecoEntrega!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (somenteEnderecos) {
      if (permitirEnderecos) return _enderecosEntrega(context);
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.shopping_bag_outlined),
        title: Text('Retirada no balcão'),
        subtitle: Text(
            'Pedidos para retirada não utilizam endereço de entrega.'),
      );
    }
    return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _titulo(context, 'Repetir o pedido', Icons.event_repeat_outlined),
            _gradeJustificada(
              context,
              larguraMinima: 140,
              botoes: [
                _cartaoOpcao(
                  context,
                  chave: 'recorrencia-todos-os-dias',
                  texto: 'Todos os dias',
                  icone: Icons.calendar_month_outlined,
                  selecionado: valor.dias.length == 7,
                  onTap: () => _atualizarDias([1, 2, 3, 4, 5, 6, 7]),
                ),
                _cartaoOpcao(
                  context,
                  chave: 'recorrencia-seg-sex',
                  texto: 'Seg a Sex',
                  icone: Icons.date_range_outlined,
                  selecionado:
                      valor.dias.length == 5 && valor.dias.every((d) => d <= 5),
                  onTap: () => _atualizarDias([1, 2, 3, 4, 5]),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _gradeJustificada(
              context,
              larguraMinima: 70,
              espacamento: 6,
              botoes: [
                for (var dia = 1; dia <= 7; dia++)
                  _cartaoOpcao(
                    context,
                    chave: 'recorrencia-dia-$dia',
                    texto: ConfiguracaoRecorrencia.nomesDias[dia - 1],
                    icone: Icons.calendar_today_outlined,
                    selecionado: valor.dias.contains(dia),
                    altura: 76,
                    onTap: () {
                      final dias = [...valor.dias];
                      dias.contains(dia) ? dias.remove(dia) : dias.add(dia);
                      _atualizarDias(dias);
                    },
                  ),
              ],
            ),
            if (permitirEnderecos) _enderecosEntrega(context),
            const SizedBox(height: 20),
            _titulo(context, 'Horário', Icons.schedule_outlined),
            _gradeJustificada(
              context,
              larguraMinima: 120,
              botoes: [
                for (final opcao in const [
                  ('livre', 'Qualquer horário', Icons.all_inclusive),
                  ('fixo', 'Horário fixo', Icons.alarm_outlined),
                  ('intervalo', 'Horário da empresa', Icons.store_outlined)
                ])
                  _cartaoOpcao(
                    context,
                    chave: 'recorrencia-horario-${opcao.$1}',
                    texto: opcao.$2,
                    icone: opcao.$3,
                    selecionado: valor.horarioTipo == opcao.$1,
                    onTap: () =>
                        onChanged(valor.copyWith(horarioTipo: opcao.$1)),
                  ),
              ],
            ),
            if (valor.horarioTipo.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Escolha quando os pedidos devem ser preparados.',
                  style: Theme.of(context).textTheme.bodySmall),
            ],
            if (['fixo', 'intervalo'].contains(valor.horarioTipo)) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                    onPressed: () => _hora(context, false),
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(
                        '${valor.horarioTipo == 'intervalo' ? 'Das' : 'Às'} ${valor.horario}')),
                if (valor.horarioTipo == 'intervalo')
                  OutlinedButton.icon(
                      onPressed: () => _hora(context, true),
                      icon: const Icon(Icons.schedule, size: 18),
                      label: Text('Até ${valor.horarioFim}')),
              ]),
            ],
            const SizedBox(height: 20),
            _titulo(context, 'Pagamento', Icons.payments_outlined),
            _gradeJustificada(context, larguraMinima: 140, botoes: [
              for (final opcao in const [
                ('diario', 'A cada pedido', Icons.receipt_long_outlined),
                ('mensal', 'Acerto mensal', Icons.event_available_outlined),
              ])
                _cartaoOpcao(
                  context,
                  chave: 'recorrencia-pagamento-${opcao.$1}',
                  texto: opcao.$2,
                  icone: opcao.$3,
                  selecionado: valor.pagamentoModo == opcao.$1,
                  onTap: () =>
                      onChanged(valor.copyWith(pagamentoModo: opcao.$1)),
                ),
            ]),
            const SizedBox(height: 8),
            if (valor.pagamentoModo == 'mensal') ...[
              DropdownButtonFormField<int>(
                initialValue: valor.diaVencimento,
                isExpanded: true,
                decoration: const InputDecoration(
                    labelText: 'Vencimento no próximo mês',
                    border: OutlineInputBorder(),
                    isDense: true),
                items: [
                  for (var dia = 1; dia <= 31; dia++)
                    DropdownMenuItem(value: dia, child: Text('Dia $dia')),
                ],
                onChanged: (dia) {
                  if (dia != null) {
                    onChanged(valor.copyWith(diaVencimento: dia));
                  }
                },
              ),
              const SizedBox(height: 8),
              Text(
                  'Cada pedido confirmado será lançado em conta. Se o mês não tiver esse dia, vence no último dia.',
                  style: Theme.of(context).textTheme.bodySmall),
            ] else if (valor.pagamentoModo == 'diario')
              Text(
                  'A forma do primeiro pagamento será sugerida nos próximos pedidos.',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              Text('Escolha como o cliente fará o pagamento.',
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(
                primeiroPedido
                    ? valor
                        .textoPrimeiroPedido(relogio?.call() ?? DateTime.now())
                    : 'A alteração vale para os próximos pedidos.',
                style: Theme.of(context).textTheme.bodySmall),
            if (exibirErro && valor.erroInformacoes != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(valor.erroInformacoes!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
          ]);
  }
}
