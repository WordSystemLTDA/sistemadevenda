import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class ComandasGrid extends StatefulWidget {
  final List<dynamic> comandas;
  const ComandasGrid({super.key, required this.comandas});

  @override
  State<ComandasGrid> createState() => _ComandasGridState();
}

class _ComandasGridState extends State<ComandasGrid> {
  @override
  Widget build(BuildContext context) {
    final comandas = widget.comandas;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: comandas.length,
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) {
        final e = comandas[index];

        if (comandas.isNotEmpty) {
          return ElevatedButton(
            onPressed: () {
              Modular.to.pushNamed('/cardapio/comanda/${e['id']}');
            },
            style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(e['comandaOcupada'] ? Colors.red : Colors.green),
              shape: MaterialStateProperty.all<RoundedRectangleBorder>(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(2.0),
                ),
              ),
            ),
            child: Text(
              e['nome'],
              style: const TextStyle(fontSize: 18, color: Colors.white),
            ),
          );
        }
        return null;
      },
    );
  }
}
