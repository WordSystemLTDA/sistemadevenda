import 'package:app/src/essencial/api/socket/monitor_atualizacao_tela.dart';
import 'package:app/src/essencial/api/socket/eventos_catalogo.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_forma_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';

class PaginaSelecionarPagamento extends StatefulWidget {
  final double totalReceber;
  final double desconto;
  final String acrescimo;
  final String descontoPercentual;
  final String totalPedido;

  const PaginaSelecionarPagamento({
    super.key,
    required this.totalReceber,
    required this.desconto,
    required this.acrescimo,
    required this.descontoPercentual,
    required this.totalPedido,
  });

  @override
  State<PaginaSelecionarPagamento> createState() =>
      _PaginaSelecionarPagamentoState();
}

class _PaginaSelecionarPagamentoState extends State<PaginaSelecionarPagamento> {
  var provedor = Modular.get<ProvedorFinalizarPagamento>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  String pagamentoSelecionado = '1';
  PagamentoRecorrente? _recorrencia;
  String? _erro;
  bool _perguntandoPagamento = false;
  bool _confirmandoPedido = false;

  bool carregando = true;
  MonitorAtualizacaoTela? _monitorFormas;
  void _aoAlterarFormas() => _monitorFormas?.solicitar();

  // Bancos padrões
  List<BancoPixModelo> bancos = [
    BancoPixModelo(id: '1', nome: 'Dinheiro'),
    BancoPixModelo(id: '2', nome: 'Conta'),
    BancoPixModelo(id: '3', nome: 'Débito'),
    BancoPixModelo(id: '4', nome: 'Crédito'),
  ];

  @override
  void initState() {
    super.initState();
    _monitorFormas = MonitorAtualizacaoTela(
      intervalo: const Duration(seconds: 10),
      estaAtiva: () =>
          mounted && !carregando && ModalRoute.of(context)?.isCurrent != false,
      atualizar: _atualizarFormas,
    );
    EventosCatalogo.pagamentos.addListener(_aoAlterarFormas);
    listarBancos();
  }

  @override
  void dispose() {
    EventosCatalogo.pagamentos.removeListener(_aoAlterarFormas);
    _monitorFormas?.dispose();
    super.dispose();
  }

  Future<void> _atualizarFormas() async {
    final dados =
        await context.read<ServicoFinalizarPagamento>().listarBancos();
    if (!mounted) return;
    final novas = bancos.take(4).toList();
    for (final opcao in [
      ('5', dados.ativoBancoPix, dados.nomeBancoPix),
      ('6', dados.ativoBancoOpcao2, dados.nomeBancoOpcao2),
      ('7', dados.ativoBancoOpcao3, dados.nomeBancoOpcao3),
      ('8', dados.ativoBancoOpcao4, dados.nomeBancoOpcao4),
      ('9', dados.ativoBancoOpcao5, dados.nomeBancoOpcao5),
    ]) {
      if (opcao.$2 == 'Sim') {
        novas.add(BancoPixModelo(id: opcao.$1, nome: opcao.$3));
      }
    }
    setState(() => bancos = novas);
  }

  void listarBancos() async {
    setState(() {
      carregando = true;
      _erro = null;
    });
    try {
      await _atualizarFormas();
      if (!mounted) return;

      final consultarRecorrencia =
          provedor.deliveryRecorrenteVinculado == true ||
              provedor.deliveryComPagamentoParcial;
      if (provedorCardapio.tipo == TipoCardapio.delivery &&
          consultarRecorrencia) {
        _recorrencia = await Modular.get<ServicoDelivery>()
            .pagamentoRecorrente(provedor.idVenda);
        if (_recorrencia?.mensal == true) {
          pagamentoSelecionado = '2';
        } else if (_recorrencia?.definida == true &&
            bancos.any((banco) => banco.id == '${_recorrencia!.forma}')) {
          pagamentoSelecionado = '${_recorrencia!.forma}';
        }
      }
    } catch (erro) {
      _erro = erro is StateError
          ? erro.message.toString()
          : 'Não foi possível consultar o pagamento.';
    }
    if (!mounted) return;
    setState(() {
      carregando = false;
    });
  }

  Future<void> _pagarDepois() async {
    if (provedorCardapio.tipo != TipoCardapio.delivery ||
        _perguntandoPagamento ||
        _confirmandoPedido) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _confirmandoPedido = true);
    try {
      final servico = Modular.get<ServicoDelivery>();
      if (provedor.idVenda.startsWith('delivery-local:')) {
        await servico.definirAjustesLocais(provedor.idVenda,
            desconto: widget.desconto > 0 ? widget.desconto : 0,
            acrescimo: widget.desconto < 0
                ? widget.desconto.abs()
                : double.tryParse(widget.acrescimo) ?? 0);
      }
      await servico.confirmar(provedor.idVenda);
      FeedbackUsuario.pedidoFinalizado();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).popUntil(
        (rota) =>
            rota.settings.name == provedor.rotaRetornoDelivery || rota.isFirst,
      );
    } catch (erro) {
      if (!mounted) return;
      _mostrarRetornoMensagem(
        erro is StateError
            ? erro.message.toString()
            : 'NÃ£o foi possÃ­vel confirmar o Delivery.',
        false,
      );
    } finally {
      if (mounted) setState(() => _confirmandoPedido = false);
    }
  }

  Future<void> _perguntarFormaPagamento() async {
    if (_perguntandoPagamento ||
        provedorCardapio.tipo != TipoCardapio.delivery) {
      return;
    }
    if ((int.tryParse(provedor.idVenda) ?? 0) <= 0 &&
        !provedor.idVenda.startsWith('delivery-local:')) {
      _mostrarRetornoMensagem(
          'Não foi possível identificar o Delivery.', false);
      return;
    }
    setState(() => _perguntandoPagamento = true);
    try {
      final retorno = await Modular.get<ServicoDelivery>().notificarCliente(
        MensagemClienteDelivery.formaPagamento,
        idDelivery: provedor.idVenda,
      );
      if (mounted) _mostrarRetornoMensagem(retorno, true);
    } catch (erro) {
      if (mounted) {
        _mostrarRetornoMensagem(
          erro is StateError
              ? erro.message.toString()
              : 'Não foi possível enviar a mensagem.',
          false,
        );
      }
    } finally {
      if (mounted) setState(() => _perguntandoPagamento = false);
    }
  }

  void _mostrarRetornoMensagem(String texto, bool sucesso) {
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: sucesso ? cs.primary : cs.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final ehDelivery = provedorCardapio.tipo == TipoCardapio.delivery;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
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
              child: Icon(Icons.payments_outlined,
                  size: 18, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('Forma de Pagamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (ehDelivery) ...[
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const ValueKey('perguntar-pagamento-delivery'),
                  onPressed:
                      carregando || _erro != null || _perguntandoPagamento
                          ? null
                          : _perguntarFormaPagamento,
                  icon: _perguntandoPagamento
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chat_outlined, size: 20),
                  label: const Text(
                    'Perguntar forma de pagamento',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cs.primaryContainer.withValues(alpha: .3),
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary.withValues(alpha: .55)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  key: const ValueKey('pagar-depois-delivery'),
                  onPressed: _perguntandoPagamento || _confirmandoPedido
                      ? null
                      : _pagarDepois,
                  icon: _confirmandoPedido
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.schedule_rounded, size: 20),
                  label: const Text(
                    'Pagar depois',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor:
                        isDark ? const Color(0xFF1F2937) : Colors.white,
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary.withValues(alpha: 0.45)),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
            Container(
              width: double.infinity,
              height: 58,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
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
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    if (carregando || _erro != null || _perguntandoPagamento) {
                      return;
                    }
                    final nomePagamento = bancos
                        .where((banco) => banco.id == pagamentoSelecionado)
                        .firstOrNull
                        ?.nome;
                    if (nomePagamento == null) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaginaFinalizarFormaPagamento(
                          totalReceber: widget.totalReceber,
                          desconto: widget.desconto,
                          acrescimo: widget.acrescimo,
                          descontoPercentual: widget.descontoPercentual,
                          totalPedido: widget.totalPedido,
                          pagamentoselecionado: pagamentoSelecionado,
                          nomePagamentoSelecionado: nomePagamento,
                          recorrencia: _recorrencia,
                        ),
                      ),
                    );
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
          ],
        ),
      ),
      body: Visibility(
        visible: carregando == false,
        replacement: const Center(child: CircularProgressIndicator()),
        child: Padding(
          padding: EdgeInsets.fromLTRB(12, 12, 12, ehDelivery ? 210 : 90),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_erro != null) ...[
                Text(_erro!, style: TextStyle(color: cs.error)),
                TextButton(
                    onPressed: listarBancos,
                    child: const Text('Tentar Novamente')),
              ],
              if (_recorrencia != null) ...[
                Text(_recorrencia!.resumo),
                const SizedBox(height: 8),
              ],
              // Hero A pagar
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
                      builder:
                          (BuildContext context, SearchController controller) {
                        return IconButton.filledTonal(
                          onPressed: () => controller.openView(),
                          icon: const Icon(Icons.history_rounded, size: 18),
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
                                borderRadius:
                                    const BorderRadius.all(Radius.circular(8)),
                                child: ListTile(
                                  leading: const Icon(Icons.person_2_outlined),
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
                              color:
                                  cs.onPrimaryContainer.withValues(alpha: 0.7),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.totalReceber.obterReal(),
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
              const SizedBox(height: 18),
              Row(
                children: [
                  Icon(Icons.credit_card_rounded, size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  const Text('Selecione o método',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  itemCount: _recorrencia?.mensal == true ? 1 : bancos.length,
                  padding: EdgeInsets.zero,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.4,
                  ),
                  itemBuilder: (context, index) {
                    final item = _recorrencia?.mensal == true
                        ? bancos.firstWhere((banco) => banco.id == '2')
                        : bancos[index];
                    final selecionado = pagamentoSelecionado == item.id;
                    return _BancoCard(
                      banco: item,
                      selecionado: selecionado,
                      onTap: () =>
                          setState(() => pagamentoSelecionado = item.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BancoCard extends StatelessWidget {
  final BancoPixModelo banco;
  final bool selecionado;
  final VoidCallback onTap;

  const _BancoCard({
    required this.banco,
    required this.selecionado,
    required this.onTap,
  });

  IconData _iconePorId(String id) {
    switch (id) {
      case '1':
        return Icons.attach_money_rounded;
      case '2':
        return Icons.receipt_long_rounded;
      case '3':
        return Icons.credit_card_rounded;
      case '4':
        return Icons.credit_score_rounded;
      case '5':
        return Icons.pix_rounded;
      default:
        return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: selecionado
            ? LinearGradient(
                colors: [cs.primary, cs.primary.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: selecionado
            ? null
            : (isDark ? const Color(0xFF1F2937) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selecionado
              ? Colors.transparent
              : (isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : cs.outline.withValues(alpha: 0.15)),
        ),
        boxShadow: selecionado
            ? [
                BoxShadow(
                  color: cs.primary.withValues(alpha: 0.30),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: selecionado
                        ? Colors.white.withValues(alpha: 0.18)
                        : cs.primaryContainer.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _iconePorId(banco.id),
                    size: 22,
                    color: selecionado ? Colors.white : cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '#${banco.id}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          color: selecionado
                              ? Colors.white.withValues(alpha: 0.8)
                              : cs.onSurface.withValues(alpha: 0.55),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        banco.nome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: selecionado ? Colors.white : cs.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selecionado)
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
