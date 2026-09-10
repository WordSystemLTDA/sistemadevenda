import 'dart:async';

import 'package:app/src/modulos/balcao/paginas/pagina_nova_venda_balcao.dart';
import 'package:app/src/modulos/balcao/paginas/widgets/card_vendas_balcao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaBalcao extends StatefulWidget {
  const PaginaBalcao({super.key});

  @override
  State<PaginaBalcao> createState() => _PaginaBalcaoState();
}

class _PaginaBalcaoState extends State<PaginaBalcao> {
  final ProvedorBalcao provedor = Modular.get<ProvedorBalcao>();

  final TextEditingController dataManualController = TextEditingController();
  final TextEditingController _horaController = TextEditingController();
  final TextEditingController _pesquisaController = TextEditingController();

  String dataInicial = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String dataFim = DateFormat('yyyy-MM-dd').format(DateTime.now());
  String dataPersonalizada = 'hoje';
  Timer? _debounce;
  Timer? debounce;

  @override
  void initState() {
    super.initState();
    dataManualController.text = '${DateFormat('dd/MM/yyyy').format(DateTime.parse(dataInicial))} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(dataFim))}';

    _horaController.text = "0${provedor.horaSelecionado.hour}:${provedor.horaSelecionado.minute}0";
    listar();
  }

  void listar() async {
    await provedor.listar();
  }

  @override
  void dispose() {
    dataManualController.dispose();
    _horaController.dispose();
    _pesquisaController.dispose();
    if (_debounce != null) {
      _debounce!.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.point_of_sale_rounded, size: 18, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('Balcão', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: cs.primary.withValues(alpha: 0.35),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PaginaNovaVendaBalcao(aoSalvar: () {}),
                  ));
            },
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Icon(Icons.add_rounded, color: Colors.white, size: 26),
            ),
          ),
        ),
      ),
      body: ListenableBuilder(
        listenable: provedor,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: () async => listar(),
            child: Column(
              children: [
                if (provedor.listando) const LinearProgressIndicator(minHeight: 2),
                _buildFiltrosCard(context),
                const SizedBox(height: 4),
                Expanded(
                  child: provedor.dados.isEmpty && !provedor.listando
                      ? _buildEstadoVazio(context)
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          scrollDirection: Axis.vertical,
                          itemCount: provedor.dados.length,
                          padding: const EdgeInsets.only(top: 4, bottom: 90, left: 4, right: 4),
                          itemBuilder: (_, index) {
                            var item = provedor.dados[index];
                            return CardVendasBalcao(
                              item: item,
                              listar: () => listar(),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltrosCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : cs.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      readOnly: true,
                      controller: dataManualController,
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 13.5),
                      textAlign: TextAlign.center,
                      onTap: () async {
                        DateTimeRange? picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(DateTime.now().year - 35),
                          lastDate: DateTime(DateTime.now().year + 50),
                          initialDateRange: DateTimeRange(
                            start: DateTime.parse(dataInicial),
                            end: DateTime.parse(dataFim),
                          ),
                        );

                        if (picked != null) {
                          setState(() {
                            dataManualController.text = "${DateFormat('dd/MM/yyyy').format(picked.start)} - ${DateFormat('dd/MM/yyyy').format(picked.end)}";
                            if (mounted) {
                              provedor.dataSelecionada = picked;
                              dataInicial = DateFormat('yyyy-MM-dd').format(picked.start);
                              dataFim = DateFormat('yyyy-MM-dd').format(picked.end);
                            }
                          });

                          provedor.listar(mostrarCarregamento: true);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 130,
                  height: 42,
                  child: DropdownMenu(
                    inputDecorationTheme: InputDecorationTheme(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                      constraints: BoxConstraints.tight(const Size.fromHeight(42)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                      ),
                    ),
                    textStyle: const TextStyle(fontSize: 13),
                    initialSelection: dataPersonalizada,
                    dropdownMenuEntries: const [
                      DropdownMenuEntry(value: 'mes_anterior', label: 'Mês Anterior'),
                      DropdownMenuEntry(value: 'ultimos7dias', label: 'Últimos 7 dias'),
                      DropdownMenuEntry(value: 'ontem', label: 'Ontem'),
                      DropdownMenuEntry(value: 'hoje', label: 'Hoje'),
                      DropdownMenuEntry(value: 'mes_atual', label: 'Mês Atual'),
                      DropdownMenuEntry(value: 'todos', label: 'Todos'),
                    ],
                    onSelected: (value) {
                      dataPersonalizada = value ?? '';
                      var agora = DateTime.now();
                      var data = DateTimeRange(
                        start: DateTime.parse(dataInicial),
                        end: DateTime.parse(dataFim),
                      );

                      if (value == 'mes_anterior') {
                        data = DateTimeRange(
                          start: DateTime(DateTime.now().year, DateTime.now().month - 1, 1),
                          end: DateTime(DateTime.now().year, DateTime.now().month, 0),
                        );
                      }
                      if (value == 'ultimos7dias') {
                        data = DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 7)),
                          end: DateTime.now(),
                        );
                      }
                      if (value == 'ontem') {
                        data = DateTimeRange(
                          start: DateTime.now().subtract(const Duration(days: 1)),
                          end: DateTime.now().subtract(const Duration(days: 1)),
                        );
                      }
                      if (value == 'hoje') {
                        data = DateTimeRange(
                          start: DateTime.now(),
                          end: DateTime.now(),
                        );
                      }
                      if (value == 'mes_atual') {
                        data = DateTimeRange(start: DateTime(agora.year, agora.month, 1), end: DateTime(agora.year, agora.month + 1, 0));
                      }
                      if (value == 'todos') {
                        data = DateTimeRange(start: DateTime(2000, agora.month, 1), end: DateTime.now());
                      }

                      setState(() {
                        dataManualController.text = "${DateFormat('dd/MM/yyyy').format(data.start)} - ${DateFormat('dd/MM/yyyy').format(data.end)}";
                        if (mounted) {
                          provedor.dataSelecionada = data;
                          dataInicial = DateFormat('yyyy-MM-dd').format(data.start);
                          dataFim = DateFormat('yyyy-MM-dd').format(data.end);
                        }
                      });

                      provedor.listar(mostrarCarregamento: true);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  height: 42,
                  child: TextField(
                    readOnly: true,
                    controller: _horaController,
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.access_time_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      isDense: true,
                    ),
                    onTap: () async {
                      var dataInicialTemp = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, provedor.horaSelecionado.hour, provedor.horaSelecionado.minute);

                      TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialEntryMode: TimePickerEntryMode.input,
                        initialTime: TimeOfDay.fromDateTime(dataInicialTemp),
                        builder: (context, child) {
                          return MediaQuery(
                            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ConstrainedBox(
                                  constraints: const BoxConstraints(maxWidth: 700, maxHeight: 500),
                                  child: child,
                                )
                              ],
                            ),
                          );
                        },
                      );

                      if (picked != null) {
                        provedor.horaSelecionado = picked;
                        _horaController.text = "${picked.hour < 10 ? '0${picked.hour}' : picked.hour}:${picked.minute < 10 ? '0${picked.minute}' : picked.minute}";

                        provedor.listar(mostrarCarregamento: true);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      controller: _pesquisaController,
                      style: const TextStyle(fontSize: 13.5),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: cs.onSurface.withValues(alpha: 0.6)),
                        hintText: 'Buscar venda, cliente...',
                        hintStyle: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.25)),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                        isDense: true,
                      ),
                      onChanged: (textoPesquisa) {
                        if (_debounce?.isActive ?? false) _debounce!.cancel();

                        _debounce = Timer(const Duration(milliseconds: 500), () {
                          if (textoPesquisa.isNotEmpty) {
                            if (debounce?.isActive ?? false) {
                              debounce!.cancel();
                            }

                            debounce = Timer(const Duration(milliseconds: 200), () async {
                              provedor.listar(pesquisa: textoPesquisa, mostrarCarregamento: true);
                            });
                          } else {
                            provedor.listar(pesquisa: '', mostrarCarregamento: true);
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoVazio(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.receipt_long_rounded, size: 46, color: cs.onPrimaryContainer),
              ),
              const SizedBox(height: 16),
              const Text('Nenhuma venda encontrada', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Crie uma nova venda no botão "+"',
                style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
