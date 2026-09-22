import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class QuantidadeProdutoPorPeso {
  final int gramas;

  const QuantidadeProdutoPorPeso(this.gramas);

  double get quilos => gramas / 1000;

  double calcularTotal(double precoPorQuilo) => precoPorQuilo * quilos;
}

class ModalQuantidadeGramas extends StatefulWidget {
  final String nomeProduto;
  final double precoPorQuilo;

  const ModalQuantidadeGramas({
    super.key,
    required this.nomeProduto,
    required this.precoPorQuilo,
  });

  @override
  State<ModalQuantidadeGramas> createState() => _ModalQuantidadeGramasState();
}

class _ModalQuantidadeGramasState extends State<ModalQuantidadeGramas> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _tentouConfirmar = false;

  int get _gramas => int.tryParse(_controller.text) ?? 0;

  QuantidadeProdutoPorPeso get _quantidade => QuantidadeProdutoPorPeso(_gramas);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _confirmar() {
    if (_gramas <= 0) {
      setState(() => _tentouConfirmar = true);
      _focus.requestFocus();
      return;
    }
    Navigator.pop(context, _quantidade);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final total = _quantidade.calcularTotal(widget.precoPorQuilo);

    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: (media.size.height -
                    media.viewInsets.bottom -
                    media.padding.vertical -
                    24)
                .clamp(0.0, double.infinity),
          ),
          child: Material(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(Icons.scale_outlined, color: cs.primary),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Quantidade em gramas',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            IconButton(
                              tooltip: 'Fechar',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.nomeProduto,
                          style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.45),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.info_outline_rounded,
                                  color: cs.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Digite o peso em gramas. Exemplo: 1000 gramas = 1 kg.',
                                  style: TextStyle(
                                    color: cs.onSurface,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextField(
                          key: const ValueKey('peso_gramas_campo'),
                          controller: _controller,
                          focusNode: _focus,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          onChanged: (_) => setState(() {
                            _tentouConfirmar = false;
                          }),
                          onSubmitted: (_) => _confirmar(),
                          decoration: InputDecoration(
                            labelText: 'Peso em gramas',
                            hintText: 'Ex.: 200',
                            suffixText: 'g',
                            errorText: _tentouConfirmar && _gramas <= 0
                                ? 'Informe um peso maior que zero.'
                                : null,
                            filled: true,
                            fillColor: cs.surfaceContainerLow,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: cs.outlineVariant),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Preço por kg: ${widget.precoPorQuilo.obterReal()}',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _gramas > 0
                                    ? '$_gramas g = ${_quantidade.quilos.toStringAsFixed(3).replaceAll('.', ',')} kg'
                                    : 'Informe o peso para calcular o valor.',
                                key: const ValueKey('peso_gramas_conversao'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              if (_gramas > 0) ...[
                                const SizedBox(height: 4),
                                Text(
                                  '${widget.precoPorQuilo.obterReal()} × $_gramas ÷ 1000',
                                  style: TextStyle(
                                    color: cs.onSurfaceVariant,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Total',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    total.obterReal(),
                                    key: const ValueKey('peso_gramas_total'),
                                    style: TextStyle(
                                      color: cs.primary,
                                      fontSize: 21,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    key: const ValueKey('confirmar_peso_gramas'),
                    onPressed: _gramas > 0 ? _confirmar : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 19),
                    label: Text(_gramas > 0
                        ? 'Adicionar por ${total.obterReal()}'
                        : 'Adicionar ao carrinho'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
