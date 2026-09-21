import 'dart:math' as math;

import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/fluxo_finalizacao_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaMetodoPagamentoAtendimento extends StatefulWidget {
  final FluxoFinalizacaoAtendimento fluxo;
  final BancoPixModelo forma;

  const PaginaMetodoPagamentoAtendimento({
    super.key,
    required this.fluxo,
    required this.forma,
  });

  @override
  State<PaginaMetodoPagamentoAtendimento> createState() =>
      _PaginaMetodoPagamentoAtendimentoState();
}

class _PaginaMetodoPagamentoAtendimentoState
    extends State<PaginaMetodoPagamentoAtendimento> {
  final _servico = Modular.get<ServicoFinalizarPagamento>();
  late final TextEditingController _valorRecebido;
  late DateTime _vencimento;
  bool _processando = false;

  int get _idForma => int.tryParse(widget.forma.id) ?? 1;
  int get _valorPagamentoCentavos => widget.fluxo.valorPagamentoCentavos;
  int get _valorRecebidoCentavos => _idForma == 1
      ? centavosMonetarios(_valorRecebido.text)
      : _valorPagamentoCentavos;
  int get _trocoCentavos =>
      math.max(0, _valorRecebidoCentavos - _valorPagamentoCentavos);

  @override
  void initState() {
    super.initState();
    _valorRecebido = TextEditingController(
      text: valorDosCentavos(_valorPagamentoCentavos)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
    _vencimento = DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _valorRecebido.dispose();
    super.dispose();
  }

  Future<void> _escolherVencimento() async {
    final agora = DateTime.now();
    final primeira = DateTime(agora.year, agora.month, agora.day + 1);
    final data = await showDatePicker(
      context: context,
      initialDate: _vencimento,
      firstDate: primeira,
      lastDate: DateTime(agora.year + 5),
      helpText: 'Vencimento da conta',
    );
    if (data != null && mounted) setState(() => _vencimento = data);
  }

  void _mensagem(String texto) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _finalizar() async {
    if (_processando) return;
    if (_valorPagamentoCentavos <= 0) {
      _mensagem('Não há saldo para receber. Atualize a conta.');
      return;
    }
    if (_idForma == 1 && _valorRecebidoCentavos < _valorPagamentoCentavos) {
      _mensagem('O valor recebido em dinheiro é insuficiente.');
      return;
    }

    final confirmou = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.verified_outlined),
        title: const Text('Confirmar recebimento'),
        content: Text(
          '${widget.forma.nome} de '
          '${valorDosCentavos(_valorPagamentoCentavos).obterReal()} será lançado '
          'na ${widget.fluxo.tipo.nome.toLowerCase()}.'
          '${_trocoCentavos > 0 ? '\nTroco: ${valorDosCentavos(_trocoCentavos).obterReal()}.' : ''}',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar')),
        ],
      ),
    );
    if (confirmou != true || !mounted) return;

    setState(() => _processando = true);
    final resultado = await _servico.pagarContaAtendimento(
      id: widget.fluxo.idAtendimento,
      idComanda: widget.fluxo.idComanda,
      idMesa: widget.fluxo.idMesa,
      cliente: widget.fluxo.idCliente,
      tipo: widget.fluxo.tipo,
      valorLancamento: valorDosCentavos(_valorRecebidoCentavos),
      valorOriginal: valorDosCentavos(widget.fluxo.valorTotalCentavos),
      valorAPagar: valorDosCentavos(_valorPagamentoCentavos),
      troco: valorDosCentavos(_trocoCentavos),
      pagamentoSelecionado: _idForma,
      quantidadePessoas:
          widget.fluxo.modo == ModoRecebimentoAtendimento.porPessoa
              ? widget.fluxo.quantidadePessoas
              : 1,
      vencimento: _idForma == 2 ? _vencimento : DateTime.now(),
      produtosParaFinalizar:
          widget.fluxo.modo == ModoRecebimentoAtendimento.porProduto
              ? widget.fluxo.produtosSelecionados
              : const [],
      modoProdutoParcial:
          widget.fluxo.modo == ModoRecebimentoAtendimento.porProduto,
      valorTaxaServico: widget.fluxo.valorTaxaServico,
      valorDesconto: valorDosCentavos(widget.fluxo.valorDescontoCentavos)
          .toStringAsFixed(2),
      valorAcrescimo: valorDosCentavos(widget.fluxo.valorAcrescimoCentavos)
          .toStringAsFixed(2),
    );
    if (!mounted) return;
    setState(() => _processando = false);

    if (!resultado.sucesso) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.sync_problem_rounded,
              color: Theme.of(context).colorScheme.error),
          title: const Text('Confira a conta novamente'),
          content: Text(
              '${resultado.mensagem}\n\nA conta será atualizada antes de permitir uma nova tentativa.'),
          actions: [
            FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Atualizar conta')),
          ],
        ),
      );
      if (mounted) {
        Navigator.pop(context, ResultadoFluxoAtendimento.recarregar);
      }
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.check_circle_rounded,
            size: 48, color: VisualAtendimento.verde(context)),
        title: Text(
            resultado.finalizou ? 'Conta finalizada' : 'Pagamento registrado'),
        content: Text(resultado.finalizou
            ? 'O recebimento foi concluído e a ${widget.fluxo.tipo.nome.toLowerCase()} foi liberada.'
            : 'O recebimento foi lançado. Ainda existe saldo nesta conta.'),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Concluir')),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.pop(
      context,
      resultado.finalizou
          ? ResultadoFluxoAtendimento.finalizou
          : ResultadoFluxoAtendimento.registrado,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dinheiro = _idForma == 1;
    return PopScope(
      canPop: !_processando,
      child: Scaffold(
        backgroundColor: VisualAtendimento.superficie(context),
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          title: const Row(children: [
            Icon(Icons.point_of_sale_rounded),
            SizedBox(width: 10),
            Expanded(
              child: Text('Método de Pagamento',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
          ]),
        ),
        body: Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 130),
            children: [
              _ValorDestaque(valor: _valorPagamentoCentavos),
              const SizedBox(height: 22),
              Row(children: [
                Icon(dinheiro
                    ? Icons.attach_money_rounded
                    : Icons.payments_outlined),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(widget.forma.nome,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ]),
              const SizedBox(height: 12),
              if (dinheiro) ...[
                TextField(
                  key: const ValueKey('valor_recebido_atendimento'),
                  controller: _valorRecebido,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Valor recebido',
                    prefixText: 'R\$ ',
                    suffixIcon: IconButton(
                      onPressed: () {
                        _valorRecebido.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _trocoCentavos > 0
                        ? VisualAtendimento.verde(context)
                            .withValues(alpha: 0.1)
                        : cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _trocoCentavos > 0
                          ? VisualAtendimento.verde(context)
                          : cs.outlineVariant,
                    ),
                  ),
                  child: Row(children: [
                    const Icon(Icons.savings_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                        child: Text('Troco',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800))),
                    Text(valorDosCentavos(_trocoCentavos).obterReal(),
                        style: TextStyle(
                            color: VisualAtendimento.verde(context),
                            fontSize: 20,
                            fontWeight: FontWeight.w900)),
                  ]),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: cs.outlineVariant)),
                  child: Row(children: [
                    const Icon(Icons.receipt_long_outlined),
                    const SizedBox(width: 10),
                    const Expanded(child: Text('Valor deste pagamento')),
                    Text(valorDosCentavos(_valorPagamentoCentavos).obterReal(),
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800)),
                  ]),
                ),
              if (_idForma == 2) ...[
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: cs.outlineVariant)),
                  leading: const Icon(Icons.event_outlined),
                  title: const Text('Vencimento da conta'),
                  subtitle: Text(
                      '${_vencimento.day.toString().padLeft(2, '0')}/${_vencimento.month.toString().padLeft(2, '0')}/${_vencimento.year}'),
                  trailing: const Icon(Icons.edit_calendar_outlined),
                  onTap: _escolherVencimento,
                ),
              ],
            ],
          ),
          if (_processando)
            Positioned.fill(
              child: ColoredBox(
                color: cs.scrim.withValues(alpha: 0.38),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.all(28),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 24),
                    decoration: BoxDecoration(
                      color: cs.surface,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black26,
                            blurRadius: 18,
                            offset: Offset(0, 8)),
                      ],
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 18),
                        Text('Confirmando pagamento...',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text(
                          'Aguarde a confirmação do servidor. Não feche o aplicativo.',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ]),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(top: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                const Expanded(
                    child: Text('Total Registrado',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                Text(valorDosCentavos(_valorRecebidoCentavos).obterReal(),
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900)),
              ]),
              const SizedBox(height: 10),
              FilledButton.icon(
                key: const ValueKey('finalizar_pagamento_atendimento'),
                onPressed: _processando ? null : _finalizar,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text('Finalizar',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(58),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _ValorDestaque extends StatelessWidget {
  final int valor;
  const _ValorDestaque({required this.valor});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          cs.primaryContainer,
          cs.primaryContainer.withValues(alpha: 0.45),
        ]),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('A PAGAR',
            style: TextStyle(
                color: cs.primary,
                letterSpacing: 2,
                fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(valorDosCentavos(valor).obterReal(),
            style: TextStyle(
                color: cs.primary, fontSize: 34, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}
