import 'package:app/src/features/home/ui/widgets/card_home.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  var nomeUsuario = '';

  @override
  void initState() {
    super.initState();
    pegarUsuario();
  }

  void pegarUsuario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var usuario = prefs.getString('usuario');

    setState(() {
      // nomeUsuario = jsonDecode(usuario!)['nome'];
    });
  }

  void sair() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove("usuario").then((value) => {
          Modular.to.pushNamed('/'),
        });
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    final double itemHeight = (size.height - 40) / 5;
    final double itemWidth = size.width / 2;

    return Scaffold(
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Text(nomeUsuario),
            ),
            ListTile(
              title: const Text('Editar Dados'),
              onTap: () {},
            ),
            ListTile(
              title: const Text('Sair'),
              onTap: sair,
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: const Text('Início'),
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
                Modular.to.pushNamed('/mesas');
              },
            ),
            CardHome(
              nome: 'Comandas',
              icone: const Icon(Icons.fact_check_outlined, size: 40),
              onPressed: () {
                Modular.to.pushNamed('/comandas');
              },
            ),
            CardHome(
              nome: 'Balcão',
              icone: const Icon(Icons.shopping_cart_outlined, size: 40),
              onPressed: () {
                Modular.to.pushNamed('/cardapio/balcao/0');
              },
            ),
          ],
        ),
      ),
    );
  }
}
