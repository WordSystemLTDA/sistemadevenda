import 'package:flutter/material.dart';

class CardHome extends StatefulWidget {
  final String nome;
  final Function() onPressed;
  final Icon icone;

  const CardHome({super.key, required this.nome, required this.onPressed, required this.icone});

  @override
  State<CardHome> createState() => _CardHomeState();
}

class _CardHomeState extends State<CardHome> {
  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: widget.onPressed,
      style: ButtonStyle(
        shape: MaterialStateProperty.all<RoundedRectangleBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          widget.icone,
          const SizedBox(height: 10),
          Text(widget.nome, style: const TextStyle(fontSize: 18)),
        ],
      ),
    );
  }
}
