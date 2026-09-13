import 'dart:async';

import 'package:flutter/material.dart';

class TempoAberto extends StatefulWidget {
  final TextStyle? textStyle;
  final String? dataAbertura;
  final DateTime Function()? agora;
  const TempoAberto(
      {super.key, this.textStyle, required this.dataAbertura, this.agora});

  @override
  State<TempoAberto> createState() => _TempoAbertoState();
}

class _TempoAbertoState extends State<TempoAberto> {
  late Timer t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  String returnFormattedText() {
    final abertura = DateTime.tryParse(widget.dataAbertura ?? '');
    if (abertura == null || abertura.year < 1970) return '--:--';
    final tempo = (widget.agora?.call() ?? DateTime.now()).difference(abertura);
    final segundos = tempo.isNegative ? 0 : tempo.inSeconds;
    final horas = (segundos ~/ 3600).toString().padLeft(2, '0');
    final minutos = ((segundos ~/ 60) % 60).toString().padLeft(2, '0');
    final restante = (segundos % 60).toString().padLeft(2, '0');
    return '$horas:$minutos:$restante';
  }

  @override
  void dispose() {
    t.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      returnFormattedText(),
      style: widget.textStyle ?? const TextStyle(color: Colors.white),
    );
  }
}
