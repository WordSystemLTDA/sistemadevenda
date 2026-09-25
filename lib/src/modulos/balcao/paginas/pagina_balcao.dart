import 'package:app/src/essencial/api/socket/monitor_atualizacao_tela.dart';
import 'dart:async';

import 'package:app/src/essencial/widgets/campo_busca.dart';
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
  String? dataPersonalizada;
  Timer? _debounce;

  late final MonitorAtualizacaoTela _monitorAtualizacao;

  @override
  void initState() {
    super.initState();
    _monitorAtualizacao = MonitorAtualizacaoTela(
      atualizar: () async { await provedor.listar(); },
      // Compatibilidade com o SDK usado na distribuicao Windows.
      // ignore: deprecated_member_use
      estaAtiva: () => mounted && TickerMode.getNotifier(context).value &&
          ModalRoute.of(context)?.isCurrent != false,
    );
    dataInicial = DateFormat('yyyy-MM-dd').format(provedor.dataSelecionada.start);
    dataFim = DateFormat('yyyy-MM-dd').format(provedor.dataSelecionada.end);
    final hoje = DateFormat('yyyy-MM-dd').format(DateTime.now());
    dataPersonalizada = dataInicial == hoje && dataFim == hoje ? 'hoje' : null;
    dataManualController.text =
        '${DateFormat('dd/MM/yyyy').format(provedor.dataSelecionada.start)} - ${DateFormat('dd/MM/yyyy').format(provedor.dataSelecionada.end)}';
    _horaController.text = '${provedor.horaSelecionado.hour.toString().padLeft(2, '0')}:${provedor.horaSelecionado.minute.toString().padLeft(2, '0')}';
    _pesquisaController.text = provedor.pesquisaAtual;
    listar();
  }

  Future<void> listar() {
    _debounce?.cancel();
    return provedor.listar(pesquisa: _pesquisaController.text, mostrarCarregamento: true);
  }

  @override
  void dispose() {
    _monitorAtualizacao.dispose();
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
      floatingActionButton: _BotaoNovaVenda(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginaNovaVendaBalcao(aoSalvar: () {}),
            ),
          );
          if (mounted) {
            await provedor.listar(mostrarCarregamento: false);
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: ListenableBuilder(
        listenable: provedor,
        builder: (context, snapshot) {
          return RefreshIndicator(
            onRefresh: listar,
            child: Column(
              children: [
                SizedBox(height: 2, child: provedor.listando ? const LinearProgressIndicator(minHeight: 2) : null),
                _buildFiltrosCard(context),
                if (provedor.erro != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(child: Text(provedor.erro!, style: TextStyle(color: cs.error))),
                        IconButton(tooltip: 'Tentar novamente', onPressed: listar, icon: const Icon(Icons.refresh)),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: provedor.dados.isEmpty && provedor.listando
                      ? const Center(child: CircularProgressIndicator())
                      : provedor.dados.isEmpty
                          ? _buildEstadoVazio(context)
                          : ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(),
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: LayoutBuilder(builder: (context, constraints) {
        final largura = constraints.maxWidth;
        final larguraData = largura >= 600 ? largura - 296 : largura;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: larguraData,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: TextField(
                  minLines: 1,
                  maxLines: 2,
                  textAlignVertical: TextAlignVertical.center,
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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

                    if (picked != null && mounted) {
                      setState(() {
                        dataPersonalizada = null;
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
            SizedBox(
              width: largura >= 600 ? 160 : largura - 128,
              height: 48,
              child: DropdownMenu(
                key: ValueKey('$dataInicial-$dataFim-$dataPersonalizada'),
                hintText: 'Período',
                width: largura >= 600 ? 160 : largura - 128,
                inputDecorationTheme: InputDecorationTheme(
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  constraints: BoxConstraints.tight(const Size.fromHeight(48)),
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
            SizedBox(
              width: 120,
              height: 48,
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
                  var dataInicialTemp =
                      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, provedor.horaSelecionado.hour, provedor.horaSelecionado.minute);

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

                  if (picked != null && mounted) {
                    provedor.horaSelecionado = picked;
                    _horaController.text = "${picked.hour < 10 ? '0${picked.hour}' : picked.hour}:${picked.minute < 10 ? '0${picked.minute}' : picked.minute}";

                    provedor.listar(mostrarCarregamento: true);
                  }
                },
              ),
            ),
            SizedBox(
              width: largura,
              child: CampoBusca(
                controller: _pesquisaController,
                hintText: 'Buscar venda ou cliente',
                onChanged: (texto) {
                  _debounce?.cancel();
                  if (texto.trim().isEmpty) {
                    listar();
                  } else {
                    _debounce = Timer(const Duration(milliseconds: 300), listar);
                  }
                },
                onSubmitted: (_) => listar(),
              ),
            ),
          ],
        );
      }),
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
            ],
          ),
        ),
      ],
    );
  }
}

class _BotaoNovaVenda extends StatelessWidget {
  final VoidCallback onPressed;

  const _BotaoNovaVenda({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final largura = (MediaQuery.sizeOf(context).width - 32).clamp(0.0, 560.0).toDouble();

    return Tooltip(
      message: 'Nova venda',
      child: Semantics(
        label: 'Nova venda',
        button: true,
        excludeSemantics: true,
        child: Container(
          key: const ValueKey('nova-venda-balcao'),
          width: largura,
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
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
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onPressed,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_rounded, color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'Nova venda',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
