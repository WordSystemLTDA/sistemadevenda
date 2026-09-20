import 'package:flutter/material.dart';
import '../../modelos/modelo_recorrente.dart';

class CamposRecorrencia extends StatelessWidget {
  final ConfiguracaoRecorrencia valor;
  final ValueChanged<ConfiguracaoRecorrencia> onChanged;
  final bool primeiroPedido;
  const CamposRecorrencia(
      {super.key,
      required this.valor,
      required this.onChanged,
      this.primeiroPedido = false});

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

  @override
  Widget build(BuildContext context) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Repetir o pedido',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              ChoiceChip(
                  label: const Text('Todos os dias'),
                  selected: valor.dias.length == 7,
                  onSelected: (_) =>
                      onChanged(valor.copyWith(dias: [1, 2, 3, 4, 5, 6, 7]))),
              ChoiceChip(
                  label: const Text('Seg a Sex'),
                  selected:
                      valor.dias.length == 5 && valor.dias.every((d) => d <= 5),
                  onSelected: (_) =>
                      onChanged(valor.copyWith(dias: [1, 2, 3, 4, 5]))),
            ]),
            const SizedBox(height: 4),
            _gradeJustificada(
              context,
              larguraMinima: 68,
              espacamento: 4,
              botoes: [
                for (var dia = 1; dia <= 7; dia++)
                  FilterChip(
                    label: Text(ConfiguracaoRecorrencia.nomesDias[dia - 1],
                        textAlign: TextAlign.center),
                    selected: valor.dias.contains(dia),
                    onSelected: (sim) {
                      final dias = [...valor.dias];
                      sim ? dias.add(dia) : dias.remove(dia);
                      onChanged(valor.copyWith(dias: dias..sort()));
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Horário', style: Theme.of(context).textTheme.titleSmall),
            _gradeJustificada(
              context,
              larguraMinima: 160,
              botoes: [
                for (final opcao in const [
                  ('livre', 'Qualquer horário'),
                  ('fixo', 'Horário fixo'),
                  ('intervalo', 'Horário da empresa')
                ])
                  ChoiceChip(
                      label: Text(opcao.$2, textAlign: TextAlign.center),
                      selected: valor.horarioTipo == opcao.$1,
                      onSelected: (_) =>
                          onChanged(valor.copyWith(horarioTipo: opcao.$1))),
              ],
            ),
            if (valor.horarioTipo != 'livre') ...[
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
            const SizedBox(height: 8),
            Text(
                primeiroPedido
                    ? 'O primeiro pedido é de hoje. Os próximos seguem os dias escolhidos.'
                    : 'A alteração vale para os próximos pedidos.',
                style: Theme.of(context).textTheme.bodySmall),
            if (valor.erro != null)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(valor.erro!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
          ]);
}
