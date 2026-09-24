import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/delivery/modelos/modelo_delivery.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/widgets/opcoes_entrega_finalizacao.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaFinalizarAcrescimo extends StatefulWidget {
  const PaginaFinalizarAcrescimo({super.key});

  @override
  State<PaginaFinalizarAcrescimo> createState() =>
      _PaginaFinalizarAcrescimoState();
}

class _PaginaFinalizarAcrescimoState extends State<PaginaFinalizarAcrescimo> {
  var provedor = Modular.get<ProvedorFinalizarPagamento>();

  final _totalPedidoController = TextEditingController();
  final _acrescimoController = TextEditingController();
  final _descontoController = TextEditingController();
  final _descontoValorController = TextEditingController();

  double _totalReceber = 0;
  double _desconto = 0;
  double _valorBase = 0;
  bool _alterandoEntrega = false;

  void _recalcular() {
    final double acrescimo = double.tryParse(_acrescimoController.text) ?? 0;
    final double desconto = double.tryParse(_descontoController.text) ?? 0;
    final double descontoValor =
        double.tryParse(_descontoValorController.text) ?? 0;

    if (desconto == 0) {
      final double valorDescontado = _valorBase - acrescimo + descontoValor;
      _totalReceber = _valorBase + (_valorBase - valorDescontado);
      _desconto = valorDescontado - _valorBase;
    } else {
      final double valorDescontado =
          _valorBase * desconto / 100 - acrescimo + descontoValor;
      _totalReceber = _valorBase - valorDescontado;
      _desconto = valorDescontado;
    }
  }

  void calcular() => setState(_recalcular);

  void _aoAtualizarEntrega(PedidoDelivery pedido) {
    final valor = pedido.restante;
    if ((_valorBase - valor).abs() <= .009) return;
    setState(() {
      _valorBase = valor;
      _totalPedidoController.text = valor.toStringAsFixed(2);
      _recalcular();
    });
  }

  @override
  void initState() {
    super.initState();
    _valorBase = provedor.valor;
    _totalPedidoController.text = _valorBase.toStringAsFixed(2);
    _totalReceber = _valorBase;
  }

  @override
  void dispose() {
    _totalPedidoController.dispose();
    _acrescimoController.dispose();
    _descontoController.dispose();
    _descontoValorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ehDelivery =
        Modular.get<ProvedorCardapio>().tipo == TipoCardapio.delivery;

    return ListenableBuilder(
      listenable: provedor,
      builder: (context, snapshot) {
        if ((_valorBase - provedor.valor).abs() > .009) {
          _valorBase = provedor.valor;
          _totalPedidoController.text = _valorBase.toStringAsFixed(2);
          _recalcular();
        }

        return Scaffold(
          backgroundColor:
              isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
          appBar: AppBar(
            backgroundColor: cs.inversePrimary,
            elevation: 0,
            centerTitle: false,
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.percent_rounded,
                      size: 18, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                const Text('Acréscimo e Descontos',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          resizeToAvoidBottomInset: false,
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
          floatingActionButton: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _totalReceber > 0
                      ? [cs.primary, cs.primary.withValues(alpha: 0.85)]
                      : [Colors.grey.shade400, Colors.grey.shade500],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: _totalReceber > 0
                    ? [
                        BoxShadow(
                          color: cs.primary.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : null,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: _alterandoEntrega
                      ? null
                      : _totalReceber > 0
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      PaginaSelecionarPagamento(
                                    totalReceber: _totalReceber,
                                    desconto: _desconto,
                                    acrescimo: _acrescimoController.text,
                                    descontoPercentual:
                                        _descontoController.text,
                                    totalPedido: _totalPedidoController.text,
                                  ),
                                ),
                              );
                            }
                          : () {
                              ScaffoldMessenger.of(context)
                                  .removeCurrentSnackBar();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Total a Receber não pode ser Negativo',
                                    textAlign: TextAlign.center),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ));
                            },
                  child: const Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Avançar',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3)),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          body: GestureDetector(
            onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: Stack(
              children: [
                Positioned(
                  bottom: 115,
                  right: 14,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1F2937) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : cs.outline.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet_outlined,
                                size: 16,
                                color: cs.onSurface.withValues(alpha: 0.7)),
                            const SizedBox(width: 6),
                            const Text('Total a Receber',
                                style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Text(
                          _totalReceber.obterReal(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                ListView(
                  padding: const EdgeInsets.only(
                      right: 12, left: 12, top: 12, bottom: 190),
                  children: [
                    // Hero "A pagar"
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primaryContainer,
                            cs.primaryContainer.withValues(alpha: 0.55)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SearchAnchor(
                            builder: (BuildContext context,
                                SearchController controller) {
                              return IconButton.filledTonal(
                                onPressed: () => controller.openView(),
                                icon:
                                    const Icon(Icons.history_rounded, size: 18),
                                tooltip: 'Histórico de pagamentos',
                              );
                            },
                            suggestionsBuilder: (BuildContext context,
                                SearchController controller) async {
                              final res = await Modular.get<ServicoBalcao>()
                                  .listarHistoricoPagamentos(
                                      provedor.idVenda, TipoCardapio.balcao);
                              return [
                                ...res.map(
                                  (e) => Card(
                                    elevation: 3.0,
                                    margin: const EdgeInsets.all(5.0),
                                    child: InkWell(
                                      onTap: () {},
                                      borderRadius: const BorderRadius.all(
                                          Radius.circular(8)),
                                      child: ListTile(
                                        leading:
                                            const Icon(Icons.person_2_outlined),
                                        title: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(e.pagamento),
                                            Text(
                                                "Valor ${double.parse(e.valor).obterReal()}"),
                                            Text(
                                                "Total: ${double.parse(e.somaValorHistorico).obterReal()}"),
                                          ],
                                        ),
                                        subtitle: Text('ID: ${e.id}'),
                                      ),
                                    ),
                                  ),
                                ),
                              ];
                            },
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'A PAGAR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.4,
                                    color: cs.onPrimaryContainer
                                        .withValues(alpha: 0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _totalReceber.obterReal(),
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: cs.onPrimaryContainer,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (ehDelivery) ...[
                      const SizedBox(height: 18),
                      OpcoesEntregaFinalizacao(
                        aoAtualizar: _aoAtualizarEntrega,
                        aoAlterarCarregamento: (alterando) {
                          if (mounted) {
                            setState(() => _alterandoEntrega = alterando);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        Icon(Icons.local_offer_outlined,
                            size: 18, color: cs.primary),
                        const SizedBox(width: 8),
                        const Text('Aplicar desconto ou acréscimo',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Você pode dar desconto em percentual ou valor.',
                      style: TextStyle(
                          fontSize: 12.5,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _totalPedidoController,
                            readOnly: true,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            decoration: _decoracaoCampo(
                              context,
                              rotulo: 'Total do Pedido',
                              icone: Icons.receipt_long_outlined,
                              prefixo: 'R\$  ',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _acrescimoController,
                            decoration: _decoracaoCampo(
                              context,
                              rotulo: 'Acréscimo (Valor)',
                              icone: Icons.add_circle_outline_rounded,
                              prefixo: 'R\$  ',
                              onLimpar: () {
                                _acrescimoController.clear();
                                calcular();
                              },
                            ),
                            onChanged: (_) => calcular(),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(',',
                                  replacementString: '.'),
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'(^\d*\.?\d{0,2})')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _descontoController,
                            decoration: _decoracaoCampo(
                              context,
                              rotulo: 'Desconto (%)',
                              icone: Icons.percent_rounded,
                              prefixo: '%  ',
                              onLimpar: () {
                                _descontoController.clear();
                                calcular();
                              },
                            ),
                            onChanged: (_) => calcular(),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(',',
                                  replacementString: '.'),
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'(^\d*\.?\d{0,2})')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _descontoValorController,
                            decoration: _decoracaoCampo(
                              context,
                              rotulo: 'Desconto (Valor)',
                              icone: Icons.remove_circle_outline_rounded,
                              prefixo: 'R\$  ',
                              onLimpar: () {
                                _descontoValorController.clear();
                                calcular();
                              },
                            ),
                            onChanged: (_) => calcular(),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.deny(',',
                                  replacementString: '.'),
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'(^\d*\.?\d{0,2})')),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  InputDecoration _decoracaoCampo(
    BuildContext context, {
    required String rotulo,
    required IconData icone,
    String? prefixo,
    VoidCallback? onLimpar,
  }) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return InputDecoration(
      labelText: rotulo,
      labelStyle:
          TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.7)),
      prefixIcon: Icon(icone, size: 18, color: cs.primary),
      prefixText: prefixo,
      prefixStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: cs.onSurface.withValues(alpha: 0.7)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1F2937) : Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.outline.withValues(alpha: 0.22)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: cs.primary, width: 1.4),
      ),
      suffixIcon: onLimpar != null
          ? IconButton(
              onPressed: onLimpar,
              icon: const Icon(Icons.close_rounded, size: 18),
              splashRadius: 18,
            )
          : null,
    );
  }
}
