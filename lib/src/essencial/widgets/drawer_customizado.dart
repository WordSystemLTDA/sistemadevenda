import 'dart:convert';

import 'package:app/src/essencial/api/socket/client.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_servico.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_lista_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DrawerCustomizado extends StatefulWidget {
  const DrawerCustomizado({super.key});

  @override
  State<DrawerCustomizado> createState() => _DrawerCustomizadoState();
}

class _DrawerCustomizadoState extends State<DrawerCustomizado> with TickerProviderStateMixin {
  Client cliente = Modular.get<Client>();
  ServicoAutenticacao servicoAutenticacao = Modular.get<ServicoAutenticacao>();

  String nome = '';
  String email = '';
  String ipServidor = '';

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

    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    setState(() {
      nome = jsonDecode(usuario!)['nome'];
      email = jsonDecode(usuario)['email'];

      ipServidor = conexao != null ? '${conexao.servidor}:${conexao.porta}' : '';
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

  void excluirConta() async {
    showDialog<String>(
      context: context,
      builder: (BuildContext contextDialog) {
        return AlertDialog(
          title: const Text('Excluir'),
          content: const SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text("Deseja realmente excluir sua conta?"),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Não'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Sim'),
              onPressed: () async {
                showDialog<String>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('Exclusão de Conta'),
                      content: const SingleChildScrollView(
                        child: ListBody(
                          children: <Widget>[
                            Text("Excluindo a sua conta você perderá o acesso a todos os seus dados, tem certeza que quer excluir?"),
                          ],
                        ),
                      ),
                      actions: <Widget>[
                        TextButton(
                          child: const Text('Não'),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        TextButton(
                          child: const Text('Sim'),
                          onPressed: () async {
                            await servicoAutenticacao.excluirConta().then((value) {
                              if (value.sucesso) {
                                if (context.mounted) {
                                  UsuarioServico.sair(context).then((value) {
                                    if (context.mounted) {
                                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const PaginaLogin()), (route) => false);
                                    }
                                  });
                                } else {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                      backgroundColor: Colors.red,
                                      content: Text(value.mensagem),
                                    ));
                                  }
                                }
                              }
                            });
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        );
      },
    );
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
          if (ipServidor.isNotEmpty)
            ListTile(
              leading: cliente.connected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.error, color: Colors.red),
              title: Text(ipServidor),
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
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Excluir Conta'),
            onTap: () {
              excluirConta();
            },
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
