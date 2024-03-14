import 'dart:async';

import 'package:flutter/material.dart';

class TempoAberto extends StatefulWidget {
  const TempoAberto({super.key});

  @override
  State<TempoAberto> createState() => _TempoAbertoState();
}

class _TempoAbertoState extends State<TempoAberto> {
  late StreamController<DateTime> _timeStreamController;
  late Stream<DateTime> _timeStream;

  @override
  void initState() {
    super.initState();
    _timeStreamController = StreamController<DateTime>();
    _timeStream = _timeStreamController.stream;
    _updateTime();
  }

  @override
  void dispose() {
    _timeStreamController.close();
    super.dispose();
  }

  void _updateTime() {
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _timeStreamController.add(DateTime.now());
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DateTime>(
      stream: _timeStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          DateTime currentTime = snapshot.data!;
          String formattedTime = "${currentTime.hour}:${currentTime.minute}:${currentTime.second < 10 ? '0${currentTime.second}' : currentTime.second}";
          return Text(
            formattedTime,
            style: const TextStyle(color: Colors.grey),
          );
        } else {
          return const Text(
            'Carregando...',
            style: TextStyle(color: Colors.grey),
          );
        }
      },
    );
  }
}
