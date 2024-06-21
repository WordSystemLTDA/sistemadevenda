import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/comandas/ui/pagina_comandas.dart';
import 'package:app/src/modulos/inicio/ui/widgets/card_home.dart';
import 'package:app/src/essencial/widgets/drawer_customizado.dart';
import 'package:app/src/modulos/listar_vendas/paginas/pagina_listar_vendas.dart';
import 'package:app/src/modulos/mesas/ui/pagina_mesas.dart';
import 'package:flutter/material.dart';

class PaginaInicio extends StatefulWidget {
  const PaginaInicio({super.key});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio> {
  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    final double itemHeight = (size.height - 40) / 5;
    final double itemWidth = size.width / 2;

    return Scaffold(
      drawer: const DrawerCustomizado(),
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
                    return const PaginaComandas();
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
                    return const PaginaCardapio(
                      tipo: 'balcao',
                      idMesa: '0',
                      idComanda: '0',
                    );
                  },
                ));
              },
            ),
            // CardHome(
            //   nome: 'Vendas',
            //   icone: const Icon(Icons.sell, size: 40),
            //   onPressed: () {
            //     Navigator.of(context).push(MaterialPageRoute(
            //       builder: (context) {
            //         return const PaginaListarVendas();
            //       },
            //     ));
            //   },
            // ),
          ],
        ),
      ),
    );
  }
}
