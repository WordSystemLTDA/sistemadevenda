import 'package:flutter/material.dart';

class CampoBusca extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;

  const CampoBusca({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final temTexto = value.text.isNotEmpty;

        return TextField(
          controller: controller,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textInputAction: TextInputAction.search,
          textAlignVertical: TextAlignVertical.center,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: cs.surface,
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIconConstraints:
                const BoxConstraints.tightFor(width: 44, height: 44),
            suffixIconConstraints:
                BoxConstraints.tightFor(width: temTexto ? 78 : 44, height: 44),
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: temTexto
                ? Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Center(
                      child: Tooltip(
                        message: 'Limpar busca',
                        child: TextButton(
                          onPressed: () {
                            controller.clear();
                            onChanged('');
                          },
                          style: TextButton.styleFrom(
                            minimumSize: const Size(62, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Limpar',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                : const SizedBox(width: 44, height: 44),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: cs.outlineVariant),
            ),
          ),
        );
      },
    );
  }
}
