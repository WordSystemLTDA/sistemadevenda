import 'package:flutter/material.dart';

class MesasGrid extends StatefulWidget {
  final List<dynamic> mesas;
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

        if (mesas.isNotEmpty) {
          return ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, "/produtos", arguments: e['id']);
            },
            style: ButtonStyle(
              backgroundColor: MaterialStatePropertyAll(e['mesaOcupada'] ? Colors.red : Colors.green),
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
