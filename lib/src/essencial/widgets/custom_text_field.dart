import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController? controller;
  final TextStyle? style;
  final String? hintText;
  final double? width;
  final double? height;
  final Function(String value)? onChanged;
  final Function()? onTap;
  final bool? readOnly;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? prefixText;
  final Widget? titulo;
  final String? initialValue;
  final TextAlign? textAlign;
  final int? maxLines;
  final int? maxLength;
  final bool? obrigatorio;
  final String? Function(String? value)? validator;
  final bool? obscureText;
  final bool? autofocus;
  final Widget? suffixIcon;
  final FocusNode? focusNode;
  final Function(String value)? onFieldSubmitted;
  final Function()? onEditingComplete;
  final Widget? prefixIcon;
  final bool? filled;
  final Color? fillColor;
  final InputBorder? border;
  final bool? isDense;
  final Widget? suffix;
  final TextInputAction? textInputAction;
  final Function(PointerDownEvent)? onTapOutside;

  const CustomTextField({
    super.key,
    this.controller,
    this.style,
    this.obrigatorio,
    this.hintText,
    this.validator,
    this.width,
    this.height,
    this.onChanged,
    this.initialValue,
    this.onTap,
    this.readOnly,
    this.keyboardType,
    this.inputFormatters,
    this.prefixText,
    this.titulo,
    this.textAlign,
    this.maxLines,
    this.maxLength,
    this.obscureText,
    this.suffixIcon,
    this.focusNode,
    this.autofocus = false,
    this.onFieldSubmitted,
    this.prefixIcon,
    this.filled,
    this.fillColor,
    this.isDense,
    this.suffix,
    this.textInputAction,
    this.onEditingComplete,
    this.onTapOutside,
    this.border = const OutlineInputBorder(),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (titulo != null) ...[
          titulo!,
        ],
        TextFormField(
          focusNode: focusNode,
          initialValue: initialValue,
          autofocus: autofocus ?? false,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          readOnly: readOnly ?? false,
          onTap: onTap,
          validator: validator,
          onTapOutside: onTapOutside,
          maxLines: maxLines ?? 1,
          onEditingComplete: onEditingComplete,
          maxLength: maxLength,
          onFieldSubmitted: onFieldSubmitted,
          textAlign: textAlign ?? TextAlign.start,
          controller: controller,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: (readOnly ?? false) == true ? Colors.grey : null).merge(style),
          onChanged: onChanged,
          canRequestFocus: (readOnly ?? false) == true ? false : true,
          obscureText: obscureText ?? false,
          decoration: InputDecoration(
            suffixIcon: suffixIcon,
            suffix: suffix,
            hintText: hintText ?? '',
            prefixText: prefixText,
            counterText: '',
            isDense: isDense,
            errorStyle: const TextStyle(fontSize: 0),
            prefixIcon: prefixIcon,
            fillColor: fillColor,
            filled: filled,
            border: border,
            constraints: const BoxConstraints(maxHeight: 44),
            contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }
}
