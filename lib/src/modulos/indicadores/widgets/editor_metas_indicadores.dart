import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../modelo_indicadores.dart';
import '../servico_indicadores.dart';

class EditorMetasIndicadores extends StatefulWidget {
  const EditorMetasIndicadores(
      {super.key,
      required this.servico,
      required this.escopo,
      required this.metas});
  final ServicoIndicadores servico;
  final String escopo;
  final MetasIndicadores metas;
  @override
  State<EditorMetasIndicadores> createState() => _EditorMetasIndicadoresState();
}

class _EditorMetasIndicadoresState extends State<EditorMetasIndicadores> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _consumo;
  late final TextEditingController _atendimentos;
  late final TextEditingController _ticket;
  bool _salvando = false;
  String? _erro;
  @override
  void initState() {
    super.initState();
    String dinheiro(int v) =>
        v == 0 ? '' : NumberFormat('0.00', 'pt_BR').format(v / 100);
    _consumo = TextEditingController(
        text: dinheiro(widget.metas.consumoDiarioCentavos));
    _atendimentos = TextEditingController(
        text: widget.metas.atendimentosDiarios == 0
            ? ''
            : '${widget.metas.atendimentosDiarios}');
    _ticket =
        TextEditingController(text: dinheiro(widget.metas.ticketMedioCentavos));
  }

  int? _centavos(String texto) {
    final limpo = texto.trim();
    if (limpo.isEmpty) return 0;
    if (!RegExp(r'^\d+(?:[,.]\d{1,2})?$').hasMatch(limpo)) return null;
    final valor = double.tryParse(limpo.replaceAll(',', '.'));
    if (valor == null || !valor.isFinite || valor > 10000000) return null;
    return (valor * 100).round();
  }

  Future<void> _salvar() async {
    if (_salvando || !_form.currentState!.validate()) return;
    setState(() {
      _salvando = true;
      _erro = null;
    });
    try {
      await widget.servico.salvarMetas(
          MetasIndicadores(
            consumoDiarioCentavos: _centavos(_consumo.text)!,
            atendimentosDiarios: int.tryParse(_atendimentos.text) ?? 0,
            ticketMedioCentavos: _centavos(_ticket.text)!,
          ),
          escopo: widget.escopo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (erro) {
      if (mounted) {
        setState(() {
          _erro = erro is FalhaIndicadores
              ? erro.mensagem
              : 'Não foi possível salvar as metas.';
          _salvando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _consumo.dispose();
    _atendimentos.dispose();
    _ticket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
        canPop: !_salvando,
        child: Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Form(
                key: _form,
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.flag_outlined, color: cs.primary),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(
                                widget.escopo == 'pessoal'
                                    ? 'Minhas metas'
                                    : 'Metas da empresa',
                                style: const TextStyle(
                                    fontSize: 21,
                                    fontWeight: FontWeight.w800))),
                        IconButton(
                            tooltip: 'Fechar',
                            onPressed: _salvando
                                ? null
                                : () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close_rounded)),
                      ]),
                      const SizedBox(height: 8),
                      Text(
                          'Defina objetivos realistas para o atendimento. Consumo e quantidade são metas por dia; o ticket é o valor médio por atendimento.',
                          style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: cs.onSurfaceVariant)),
                      const SizedBox(height: 22),
                      _campo(_consumo, 'Consumo por dia', 'Ex.: 1500,00',
                          'meta-consumo',
                          monetario: true),
                      const SizedBox(height: 16),
                      _campo(_atendimentos, 'Atendimentos por dia', 'Ex.: 20',
                          'meta-atendimentos'),
                      const SizedBox(height: 16),
                      _campo(_ticket, 'Ticket médio desejado', 'Ex.: 75,00',
                          'meta-ticket',
                          monetario: true),
                      const SizedBox(height: 14),
                      Text(
                          'Deixe em branco ou informe 0 para desativar uma meta. As metas consideram todos os tipos de atendimento desta visão.',
                          style: TextStyle(
                              fontSize: 11,
                              height: 1.5,
                              color: cs.onSurfaceVariant)),
                      if (_erro != null)
                        Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Text(_erro!,
                                style: TextStyle(color: cs.error))),
                      const SizedBox(height: 22),
                      FilledButton.icon(
                          key: const ValueKey('salvar-metas'),
                          onPressed: _salvando ? null : _salvar,
                          style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 17),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14))),
                          icon: _salvando
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.check_rounded),
                          label:
                              Text(_salvando ? 'Salvando...' : 'Salvar metas')),
                    ])),
          ),
        ));
  }

  Widget _campo(TextEditingController controle, String titulo, String exemplo,
          String chave,
          {bool monetario = false}) =>
      TextFormField(
        key: ValueKey(chave),
        controller: controle,
        enabled: !_salvando,
        keyboardType: TextInputType.numberWithOptions(decimal: monetario),
        textInputAction:
            controle == _ticket ? TextInputAction.done : TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              monetario ? RegExp(r'[0-9,.]') : RegExp(r'[0-9]'))
        ],
        onFieldSubmitted: (_) {
          if (controle == _ticket) _salvar();
        },
        decoration: InputDecoration(
            labelText: titulo,
            hintText: exemplo,
            prefixText: monetario ? 'R\$ ' : null,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(13))),
        validator: (texto) {
          if (monetario) {
            return _centavos(texto ?? '') == null
                ? 'Informe um valor válido, como 1500,00.'
                : null;
          }
          if (texto == null || texto.isEmpty) return null;
          final n = int.tryParse(texto);
          return n == null || n > 100000
              ? 'Informe até 100.000 atendimentos.'
              : null;
        },
      );
}
