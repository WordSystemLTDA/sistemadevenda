import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/fluxo_finalizacao_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_metodo_pagamento_atendimento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/uteis/calculo_finalizacao_atendimento.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaSelecionarPagamentoAtendimento extends StatefulWidget {
  final FluxoFinalizacaoAtendimento fluxo;

  const PaginaSelecionarPagamentoAtendimento({
    super.key,
    required this.fluxo,
  });

  @override
  State<PaginaSelecionarPagamentoAtendimento> createState() =>
      _PaginaSelecionarPagamentoAtendimentoState();
}

class _PaginaSelecionarPagamentoAtendimentoState
    extends State<PaginaSelecionarPagamentoAtendimento> {
  final _servico = Modular.get<ServicoFinalizarPagamento>();
  List<BancoPixModelo> _formas = const [];
  int _selecionado = 1;
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  Future<void> _carregar() async {
    final formas = <BancoPixModelo>[
      BancoPixModelo(id: '1', nome: 'Dinheiro'),
      BancoPixModelo(id: '2', nome: 'Conta'),
      BancoPixModelo(id: '3', nome: 'Débito'),
      BancoPixModelo(id: '4', nome: 'Crédito'),
    ];
    try {
      final bancos = await _servico.listarBancos();
      final adicionais = [
        (5, bancos.ativoBancoPix, bancos.nomeBancoPix),
        (6, bancos.ativoBancoOpcao2, bancos.nomeBancoOpcao2),
        (7, bancos.ativoBancoOpcao3, bancos.nomeBancoOpcao3),
        (8, bancos.ativoBancoOpcao4, bancos.nomeBancoOpcao4),
        (9, bancos.ativoBancoOpcao5, bancos.nomeBancoOpcao5),
      ];
      formas.addAll(adicionais
          .where((item) => item.$2 == 'Sim' && item.$3.trim().isNotEmpty)
          .map((item) =>
              BancoPixModelo(id: '${item.$1}', nome: item.$3.trim())));
    } catch (_) {
      // As formas básicas continuam disponíveis mesmo sem esta consulta.
    }
    if (!mounted) return;
    setState(() {
      _formas = formas;
      _carregando = false;
    });
  }

  void _selecionar(int id) {
    if (id == 2 &&
        (widget.fluxo.idCliente.isEmpty || widget.fluxo.idCliente == '0')) {
      ScaffoldMessenger.of(context)
        ..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
              'Vincule um cliente à ${widget.fluxo.tipo.nome.toLowerCase()} antes de lançar em Conta.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
      return;
    }
    setState(() => _selecionado = id);
  }

  Future<void> _avancar() async {
    BancoPixModelo? forma;
    for (final item in _formas) {
      if (item.id == '$_selecionado') forma = item;
    }
    if (forma == null) return;
    final resultado = await Navigator.of(context)
        .push<ResultadoFluxoAtendimento>(MaterialPageRoute(
      builder: (_) => PaginaMetodoPagamentoAtendimento(
        fluxo: widget.fluxo,
        forma: forma!,
      ),
    ));
    if (mounted && resultado != null) Navigator.pop(context, resultado);
  }

  IconData _icone(int id) => switch (id) {
        1 => Icons.attach_money_rounded,
        2 => Icons.receipt_long_outlined,
        3 => Icons.credit_card_outlined,
        4 => Icons.credit_score_outlined,
        _ => Icons.qr_code_2_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: VisualAtendimento.superficie(context),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: const Row(children: [
          Icon(Icons.payments_outlined),
          SizedBox(width: 10),
          Expanded(
            child: Text('Forma de Pagamento',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 116),
        children: [
          _ValorDestaque(valor: widget.fluxo.valorPagamentoCentavos),
          const SizedBox(height: 22),
          const Row(children: [
            Icon(Icons.credit_card_rounded),
            SizedBox(width: 10),
            Expanded(
              child: Text('Selecione o método',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 14),
          if (_carregando)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(30),
                    child: CircularProgressIndicator()))
          else
            LayoutBuilder(builder: (context, limites) {
              final textoAmpliado =
                  MediaQuery.textScalerOf(context).scale(16) > 20;
              final duasColunas = limites.maxWidth >= 360 && !textoAmpliado;
              final largura =
                  duasColunas ? (limites.maxWidth - 10) / 2 : limites.maxWidth;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final forma in _formas)
                    SizedBox(
                      width: largura,
                      child: _CardFormaPagamento(
                        id: int.tryParse(forma.id) ?? 0,
                        nome: forma.nome,
                        icone: _icone(int.tryParse(forma.id) ?? 0),
                        selecionado: _selecionado == int.tryParse(forma.id),
                        onTap: () => _selecionar(int.tryParse(forma.id) ?? 1),
                      ),
                    ),
                ],
              );
            }),
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
          child: FilledButton.icon(
            key: const ValueKey('avancar_forma_pagamento_atendimento'),
            onPressed: _carregando ? null : _avancar,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: const Text('Avançar',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
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

class _CardFormaPagamento extends StatelessWidget {
  final int id;
  final String nome;
  final IconData icone;
  final bool selecionado;
  final VoidCallback onTap;

  const _CardFormaPagamento({
    required this.id,
    required this.nome,
    required this.icone,
    required this.selecionado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: selecionado ? cs.primary : cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: selecionado ? cs.primary : cs.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selecionado
                    ? cs.onPrimary.withValues(alpha: 0.18)
                    : cs.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  Icon(icone, color: selecionado ? cs.onPrimary : cs.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('#$id',
                        style: TextStyle(
                            fontSize: 12,
                            color: selecionado
                                ? cs.onPrimary.withValues(alpha: 0.8)
                                : cs.onSurfaceVariant)),
                    Text(nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: selecionado ? cs.onPrimary : cs.onSurface,
                            fontWeight: FontWeight.w800)),
                  ]),
            ),
            if (selecionado)
              Icon(Icons.check_circle_rounded, color: cs.onPrimary),
          ]),
        ),
      ),
    );
  }
}
