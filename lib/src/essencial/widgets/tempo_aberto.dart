import 'dart:async';

import 'package:flutter/material.dart';

class TempoAberto extends StatefulWidget {
  final TextStyle? textStyle;
  const TempoAberto({super.key, this.textStyle});

  @override
  State<TempoAberto> createState() => _TempoAbertoState();
}

class _TempoAbertoState extends State<TempoAberto> {
  late Stopwatch stopwatch;
  late Timer t;

  @override
  void initState() {
    super.initState();
    stopwatch = Stopwatch();
    stopwatch.start();

    t = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {});
    });
  }

  String returnFormattedText() {
    var milli = stopwatch.elapsed.inMilliseconds;

    String seconds = ((milli ~/ 1000) % 60).toString().padLeft(2, "0"); // this is for the second
    String minutes = ((milli ~/ 1000) ~/ 60).toString().padLeft(2, "0"); // this is for the minute

    return "$minutes:$seconds";
  }

  @override
  void dispose() {
    t.cancel();
    stopwatch.stop();
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
