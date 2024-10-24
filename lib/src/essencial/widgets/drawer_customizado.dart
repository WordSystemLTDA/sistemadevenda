import 'dart:convert';

import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_lista_mesas.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DrawerCustomizado extends StatefulWidget {
  const DrawerCustomizado({super.key});

  @override
  State<DrawerCustomizado> createState() => _DrawerCustomizadoState();
}

class _DrawerCustomizadoState extends State<DrawerCustomizado> with TickerProviderStateMixin {
  String nome = '';
  String email = '';

  late final AnimationController _controller;
  late final Animation<double> _animation;
  late final Tween<double> _sizeTween;
  bool _isExpanded = false;

  void _expandOnChanged() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _isExpanded ? _controller.forward() : _controller.reverse();
  }

  @override
  void initState() {
    super.initState();

    pegarUsuario();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
    _sizeTween = Tween(begin: 0, end: 1);
  }

  @override
  void dispose() {
    super.dispose();

    _controller.dispose();

    _isExpanded = false;
  }

  void pegarUsuario() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    var usuario = prefs.getString('usuario');

    setState(() {
      nome = jsonDecode(usuario!)['nome'];
      email = jsonDecode(usuario)['email'];
    });
  }

  void sair() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.remove("usuario").then((value) {
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) {
            return const PaginaLogin();
          },
        ));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(nome),
            accountEmail: Text(email),
            currentAccountPicture: const CircleAvatar(
              child: ClipOval(
                child: Icon(Icons.person),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.text_snippet),
            title: const Text('Cadastrar'),
            trailing: _isExpanded ? const Icon(Icons.keyboard_arrow_up) : const Icon(Icons.keyboard_arrow_down),
            onTap: () => _expandOnChanged(),
          ),
          SizeTransition(
            sizeFactor: _sizeTween.animate(_animation),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: const Row(children: [SizedBox(width: 42), Text('Mesa')]),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PaginaListaMesas()));
                  },
                ),
                ListTile(
                  title: const Row(children: [SizedBox(width: 42), Text('Comanda')]),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TodasComandas()));
                  },
                ),
                // ListTile(
                //   title: const Row(children: [SizedBox(width: 42), Text('Vendas')]),
                //   onTap: () {
                //     Navigator.pop(context);
                //     Navigator.of(context).push(MaterialPageRoute(builder: (context) => const PaginaListarVendas()));
                //   },
                // ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Configurações'),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (context) {
                  return const PaginaConfiguracao();
                },
              ));
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Editar Dados'),
            onTap: () {},
          ),
          ListTile(
            iconColor: Colors.red,
            textColor: Colors.red,
            leading: const Icon(Icons.logout),
            title: const Text('Sair'),
            onTap: sair,
          ),
        ],
      ),
    );
  }
}
