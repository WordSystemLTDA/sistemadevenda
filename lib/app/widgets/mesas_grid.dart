import 'package:app/app/pages/produtos_page.dart';
import 'package:flutter/material.dart';
import 'package:page_transition/page_transition.dart';

class MesasGrid extends StatefulWidget {
  final dynamic mesas;
  const MesasGrid({super.key, required this.mesas});

  @override
  State<MesasGrid> createState() => _MesasGridState();
}

class _MesasGridState extends State<MesasGrid> {
  @override
  Widget build(BuildContext context) {
    final mesas = widget.mesas;

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: mesas.length,
      shrinkWrap: true,
      itemBuilder: (BuildContext context, int index) {
        final e = mesas[index];

        return ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              PageTransition(
                child: ProdutosPage(idMesa: e['id']),
                type: PageTransitionType.rightToLeft,
              ),
            );
          },
          style: ButtonStyle(
            backgroundColor: MaterialStatePropertyAll(e['mesaOcupada'] ? Colors.red : Colors.green),
            shape: MaterialStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2.0),
              ),
            ),
          ),
          child: Text(e['nome'], style: const TextStyle(fontSize: 18, color: Colors.white)),
        );
      },
    );
  }
}
