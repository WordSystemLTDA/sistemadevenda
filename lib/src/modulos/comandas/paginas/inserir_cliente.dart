import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';

class InserirCliente extends StatefulWidget {
  const InserirCliente({super.key});

  @override
  State<InserirCliente> createState() => _InserirClienteState();
}

class _InserirClienteState extends State<InserirCliente> {
  final _nomeController = TextEditingController();
  final _celularController = TextEditingController();
  final _emailController = TextEditingController();
  final _observacaoController = TextEditingController();

  final ProvedorComanda _state = Modular.get<ProvedorComanda>();

  bool _salvando = false;

  @override
  void dispose() {
    _nomeController.dispose();
    _celularController.dispose();
    _emailController.dispose();
    _observacaoController.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;

    if (_nomeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Informe o nome do cliente'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _salvando = true);

    final resposta = await _state.inserirCliente(
      _nomeController.text.trim(),
      _celularController.text,
      _emailController.text.trim(),
      _observacaoController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _salvando = false);

    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(resposta.mensagem),
        backgroundColor: resposta.sucesso ? Colors.green.shade600 : cs.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );

    if (resposta.sucesso) {
      Navigator.pop(context, {
        'idcliente': resposta.idcliente,
        'nomecliente': resposta.nomecliente,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        title: const Text('Cadastrar cliente', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: _salvando ? null : _salvar,
            icon: _salvando
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: cs.onPrimary),
                  )
                : const Icon(Icons.check_rounded, size: 20),
            label: Text(
              _salvando ? 'Salvando...' : 'Salvar cliente',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 4,
            ),
          ),
        ),
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
          children: [
            _CartaoCabecalho(),
            const SizedBox(height: 18),
            const _LabelCampo(icone: Icons.badge_outlined, texto: 'Nome', obrigatorio: true),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _nomeController,
              hint: 'Nome completo',
              icone: Icons.person_outline_rounded,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 18),
            const _LabelCampo(icone: Icons.phone_outlined, texto: 'Celular'),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _celularController,
              hint: '(00) 00000-0000',
              icone: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                TelefoneInputFormatter(),
              ],
            ),
            const SizedBox(height: 18),
            const _LabelCampo(icone: Icons.alternate_email_rounded, texto: 'E-mail'),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _emailController,
              hint: 'cliente@email.com',
              icone: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            const _LabelCampo(icone: Icons.notes_rounded, texto: 'Observação'),
            const SizedBox(height: 8),
            _CampoTexto(
              controller: _observacaoController,
              hint: 'Anotações sobre o cliente...',
              icone: Icons.sticky_note_2_outlined,
              maxLines: 4,
            ),
          ],
        ),
      ),
    );
  }
}

class _CartaoCabecalho extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.person_add_alt_1_rounded, size: 28, color: cs.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'NOVO CADASTRO',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dados do cliente',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Apenas o nome é obrigatório.',
                  style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelCampo extends StatelessWidget {
  final IconData icone;
  final String texto;
  final bool obrigatorio;

  const _LabelCampo({required this.icone, required this.texto, this.obrigatorio = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icone, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.onSurface, letterSpacing: 0.1),
        ),
        if (obrigatorio) ...[
          const SizedBox(width: 4),
          Text('*', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: cs.error)),
        ],
      ],
    );
  }
}

class _CampoTexto extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icone;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final int maxLines;

  const _CampoTexto({
    required this.controller,
    required this.hint,
    required this.icone,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: maxLines > 1 ? 4 : 2),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 14 : 0),
            child: Icon(icone, size: 20, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              textCapitalization: textCapitalization,
              inputFormatters: inputFormatters,
              maxLines: maxLines,
              minLines: maxLines > 1 ? maxLines - 1 : 1,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: cs.onSurfaceVariant, fontSize: 13.5),
                border: InputBorder.none,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
