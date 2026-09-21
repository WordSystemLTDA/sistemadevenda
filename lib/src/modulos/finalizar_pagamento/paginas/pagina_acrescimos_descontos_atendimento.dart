import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/fluxo_finalizacao_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_selecionar_pagamento_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';

class PaginaAcrescimosDescontosAtendimento extends StatefulWidget {
  final FluxoFinalizacaoAtendimento fluxo;

  const PaginaAcrescimosDescontosAtendimento({
    super.key,
    required this.fluxo,
  });

  @override
  State<PaginaAcrescimosDescontosAtendimento> createState() =>
      _PaginaAcrescimosDescontosAtendimentoState();
}

class _PaginaAcrescimosDescontosAtendimentoState
    extends State<PaginaAcrescimosDescontosAtendimento> {
  late final TextEditingController _acrescimo;
  late final TextEditingController _descontoPercentual;
  late final TextEditingController _descontoValor;
  late final TextEditingController _totalConta;

  @override
  void initState() {
    super.initState();
    _acrescimo = TextEditingController(
        text: _textoCentavos(widget.fluxo.valorAcrescimoCentavos));
    _descontoPercentual = TextEditingController();
    _descontoValor = TextEditingController(
        text: _textoCentavos(widget.fluxo.valorDescontoCentavos));
    _totalConta = TextEditingController(
      text: valorDosCentavos(widget.fluxo.valorBaseCentavos)
          .toStringAsFixed(2)
          .replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _acrescimo.dispose();
    _descontoPercentual.dispose();
    _descontoValor.dispose();
    _totalConta.dispose();
    super.dispose();
  }

  String _textoCentavos(int centavos) => centavos == 0
      ? ''
      : valorDosCentavos(centavos).toStringAsFixed(2).replaceAll('.', ',');

  int get _acrescimoCentavos => centavosMonetarios(_acrescimo.text);
  int get _descontoFixoCentavos => centavosMonetarios(_descontoValor.text);
  int get _descontoPercentualCentavos => (widget.fluxo.valorBaseCentavos *
          numeroMonetario(_descontoPercentual.text) /
          100)
      .round();
  int get _descontoCentavos =>
      _descontoFixoCentavos + _descontoPercentualCentavos;

  FluxoFinalizacaoAtendimento get _fluxoAjustado => widget.fluxo.comAjustes(
        descontoCentavos: _descontoCentavos,
        acrescimoCentavos: _acrescimoCentavos,
      );

  void _mensagem(String texto) {
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(texto),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ));
  }

  Future<void> _avancar() async {
    final fluxo = _fluxoAjustado;
    if (_acrescimoCentavos < 0 || _descontoFixoCentavos < 0) {
      _mensagem('Acréscimo e desconto não podem ser negativos.');
      return;
    }
    if (numeroMonetario(_descontoPercentual.text) < 0 ||
        numeroMonetario(_descontoPercentual.text) > 100) {
      _mensagem('Informe um desconto percentual entre 0 e 100%.');
      return;
    }
    if (fluxo.valorTotalCentavos <= fluxo.valorPagoCentavos ||
        fluxo.valorPagamentoCentavos <= 0) {
      _mensagem(
          'Os descontos não podem deixar a conta abaixo do valor já recebido.');
      return;
    }
    final resultado = await Navigator.of(context)
        .push<ResultadoFluxoAtendimento>(MaterialPageRoute(
      builder: (_) => PaginaSelecionarPagamentoAtendimento(fluxo: fluxo),
    ));
    if (mounted && resultado != null) Navigator.pop(context, resultado);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fluxo = _fluxoAjustado;
    return Scaffold(
      backgroundColor: VisualAtendimento.superficie(context),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: const Row(children: [
          Icon(Icons.percent_rounded),
          SizedBox(width: 10),
          Expanded(
            child: Text('Acréscimo e Descontos',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 130),
        children: [
          _ValorDestaque(valor: fluxo.valorPagamentoCentavos),
          const SizedBox(height: 22),
          const Row(children: [
            Icon(Icons.sell_outlined),
            SizedBox(width: 10),
            Expanded(
              child: Text('Aplicar desconto ou acréscimo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text('Você pode informar percentual ou valor.',
              style: TextStyle(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          _CampoValor(
            label: 'Total da conta',
            controller: _totalConta,
            icon: Icons.receipt_long_outlined,
            enabled: false,
          ),
          const SizedBox(height: 10),
          _CampoValor(
            key: const ValueKey('acrescimo_atendimento'),
            label: 'Acréscimo (Valor)',
            controller: _acrescimo,
            icon: Icons.add_circle_outline,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _CampoValor(
            key: const ValueKey('desconto_percentual_atendimento'),
            label: 'Desconto (%)',
            controller: _descontoPercentual,
            icon: Icons.percent_rounded,
            prefix: '',
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          _CampoValor(
            key: const ValueKey('desconto_valor_atendimento'),
            label: 'Desconto (Valor)',
            controller: _descontoValor,
            icon: Icons.remove_circle_outline,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(top: BorderSide(color: cs.outlineVariant)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.account_balance_wallet_outlined),
                const SizedBox(width: 8),
                const Expanded(
                    child: Text('Total a Receber',
                        style: TextStyle(fontWeight: FontWeight.w700))),
                Text(valorDosCentavos(fluxo.valorPagamentoCentavos).obterReal(),
                    style: TextStyle(
                        color: cs.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('avancar_acrescimos_atendimento'),
              onPressed: _avancar,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Avançar',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ]),
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

class _CampoValor extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool enabled;
  final String prefix;
  final ValueChanged<String>? onChanged;

  const _CampoValor({
    super.key,
    required this.label,
    required this.controller,
    required this.icon,
    this.enabled = true,
    this.prefix = 'R\$ ',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          prefixText: prefix,
          suffixIcon: enabled && controller.text.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                  icon: const Icon(Icons.close_rounded),
                )
              : null,
          border: const OutlineInputBorder(),
        ),
      );
}
