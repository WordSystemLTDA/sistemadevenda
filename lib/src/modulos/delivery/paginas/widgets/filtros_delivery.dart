import 'package:app/src/modulos/delivery/provedores/provedor_delivery.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FiltrosDelivery extends StatefulWidget {
  final ProvedorDelivery provedor;
  const FiltrosDelivery({super.key, required this.provedor});
  @override
  State<FiltrosDelivery> createState() => _FiltrosDeliveryState();
}

class _FiltrosDeliveryState extends State<FiltrosDelivery> {
  late DateTimeRange _periodo = widget.provedor.periodo;
  late String _tipo = widget.provedor.tipo;
  late String _inicio = widget.provedor.horaInicio,
      _fim = widget.provedor.horaFim;
  Future<void> _hora(bool inicio) async {
    final valor = (inicio ? _inicio : _fim).split(':');
    final res = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay(hour: int.parse(valor[0]), minute: int.parse(valor[1])));
    if (!mounted || res == null) return;
    final horario =
        '${res.hour.toString().padLeft(2, '0')}:${res.minute.toString().padLeft(2, '0')}:00';
    setState(() {
      if (inicio) {
        _inicio = horario;
      } else {
        _fim = horario;
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('Filtrar pedidos'),
        content: SizedBox(
            width: 440,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(
                          '${DateFormat('dd/MM/yyyy').format(_periodo.start)} - ${DateFormat('dd/MM/yyyy').format(_periodo.end)}'),
                      onPressed: () async {
                        final res = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2020),
                            lastDate:
                                DateTime.now().add(const Duration(days: 365)),
                            initialDateRange: _periodo);
                        if (mounted && res != null) {
                          setState(() => _periodo = res);
                        }
                      }),
                  Wrap(spacing: 8, children: [
                    for (final d in const [
                      (0, 'Hoje'),
                      (1, 'Ontem'),
                      (6, '7 dias')
                    ])
                      TextButton(
                          onPressed: () {
                            final hoje = DateUtils.dateOnly(DateTime.now());
                            setState(() => _periodo = DateTimeRange(
                                start: hoje.subtract(Duration(days: d.$1)),
                                end: d.$1 == 1
                                    ? hoje.subtract(const Duration(days: 1))
                                    : hoje));
                          },
                          child: Text(d.$2))
                  ]),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                        onPressed: () => _hora(true),
                        icon: const Icon(Icons.schedule),
                        label: Text('Início ${_inicio.substring(0, 5)}')),
                    OutlinedButton.icon(
                        onPressed: () => _hora(false),
                        icon: const Icon(Icons.schedule),
                        label: Text('Fim ${_fim.substring(0, 5)}')),
                  ]),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                      initialValue: _tipo,
                      isExpanded: true,
                      decoration: const InputDecoration(
                          labelText: 'Tipo de entrega',
                          border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: '0', child: Text('Todos')),
                        DropdownMenuItem(value: '1', child: Text('Entrega')),
                        DropdownMenuItem(value: '2', child: Text('Retirada')),
                        DropdownMenuItem(value: '3', child: Text('No local'))
                      ],
                      onChanged: (v) => setState(() => _tipo = v!)),
                ])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () {
                widget.provedor.periodo = _periodo;
                widget.provedor.tipo = _tipo;
                widget.provedor.horaInicio = _inicio;
                widget.provedor.horaFim = _fim;
                Navigator.pop(context, true);
              },
              child: const Text('Aplicar'))
        ],
      );
}
