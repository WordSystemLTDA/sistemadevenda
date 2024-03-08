import 'package:app/src/modulos/cardapio/ui/cardapio_page.dart';
import 'package:app/src/modulos/comandas/ui/comandas_page.dart';
import 'package:app/src/modulos/home/ui/widgets/card_home.dart';
import 'package:app/src/modulos/home/ui/widgets/drawer_widget.dart';
import 'package:app/src/modulos/mesas/ui/pagina_mesas.dart';
import 'package:flutter/material.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    final double itemHeight = (size.height - 40) / 5;
    final double itemWidth = size.width / 2;

    return Scaffold(
      drawer: const DrawerWidget(),
      appBar: AppBar(
        title: const Text('Início'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          shrinkWrap: true,
          childAspectRatio: (itemWidth / itemHeight),
          children: [
            CardHome(
              nome: 'Mesas',
              icone: const Icon(Icons.table_bar_outlined, size: 40),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) {
                    return const PaginaMesas();
                  },
                ));
              },
            ),
            CardHome(
              nome: 'Comandas',
              icone: const Icon(Icons.fact_check_outlined, size: 40),
              onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) {
                    return const ComandasPage();
                  },
                ));
              },
            ),
            CardHome(
              nome: 'Balcão',
              icone: const Icon(Icons.shopping_cart_outlined, size: 40),
              onPressed: () {
                // Navigator.of(context).pushNamed('/cardapio/balcao/0');

                Navigator.of(context).push(MaterialPageRoute(
                  builder: (context) {
                    return const CardapioPage(
                      tipo: 'balcao',
                      idMesa: '0',
                      idComanda: '0',
                    );
                  },
                ));
              },
            ),
          ],
        ),
      ),
    );
  }
}
