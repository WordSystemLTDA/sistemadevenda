import 'package:app/src/features/mesas/interactor/states/mesas_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

class MesasPage extends StatefulWidget {
  const MesasPage({super.key});

  @override
  State<MesasPage> createState() => _MesasPageState();
}

class _MesasPageState extends State<MesasPage> {
  final MesaState _state = MesaState();
  bool isLoading = false;

  void listar() async {
    setState(() => isLoading = !isLoading);
    await _state.listarMesas();
    setState(() => isLoading = !isLoading);
  }

  @override
  void initState() {
    super.initState();

    listar();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: listaMesaState,
      builder: (context, value, child) => Scaffold(
        appBar: AppBar(
          title: const Text('Mesas'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => listar(),
            ),
          ],
        ),
        body: Stack(
          children: [
            if (isLoading) const LinearProgressIndicator(),
            GridView.builder(
              shrinkWrap: true,
              scrollDirection: Axis.vertical,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width <= 1440 ? 2 : 3,
                mainAxisExtent: 70,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              padding: const EdgeInsets.all(10),
              itemCount: value.length,
              itemBuilder: (context, index) {
                final item = value[index];

                return Card(
                  child: InkWell(
                    onTap: () {
                      Modular.to.pushNamed('/cardapio/Mesa/0/${item["id"]}');
                    },
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(width: 15),
                        const Icon(Icons.table_bar_outlined),
                        const SizedBox(width: 10),
                        Text(item['nome'], style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
