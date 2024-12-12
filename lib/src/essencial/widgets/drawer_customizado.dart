import 'dart:io';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/config/config_provedor.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_servico.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_configuracao.dart';
import 'package:app/src/modulos/autenticacao/paginas/pagina_login.dart';
import 'package:app/src/modulos/autenticacao/servicos/servico_autenticacao.dart';
import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_lista_mesas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class DrawerCustomizado extends StatefulWidget {
  const DrawerCustomizado({super.key});

  @override
  State<DrawerCustomizado> createState() => _DrawerCustomizadoState();
}

class _DrawerCustomizadoState extends State<DrawerCustomizado> with TickerProviderStateMixin {
  Server server = Modular.get<Server>();
  ConfigProvider configProvider = Modular.get<ConfigProvider>();
  UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  ServicoAutenticacao servicoAutenticacao = Modular.get<ServicoAutenticacao>();

  String versaoInstalada = '';
  String versaoServidor = '';

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

    verificarVersaoApp(configProvider.configs?.versaoAppAndroid ?? '', configProvider.configs?.versaoAppIos ?? '');

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

  void verificarVersaoApp(String versaoApp, String versaoAppIos) async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String numeroVersaoApp = packageInfo.version;
    String numeroVersaoAppServidor = Platform.isIOS ? versaoAppIos : versaoApp;

    if (numeroVersaoAppServidor.split('.').length <= 2) {
      numeroVersaoAppServidor += '.0';
    }

    setState(() {
      versaoInstalada = numeroVersaoApp.toString();
      versaoServidor = numeroVersaoAppServidor.toString();
    });

    if (mounted) {
      if (Version.parse(numeroVersaoAppServidor) > Version.parse(numeroVersaoApp)) {
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return ListenableBuilder(
              listenable: configProvider,
              builder: (context, state) {
                return AlertDialog(
                  title: const Text(
                    'Atualização disponível',
                    style: TextStyle(fontSize: 16),
                  ),
                  content: Text(Platform.isAndroid ? 'Escolha uma opção para poder atualizar o aplicativo.' : 'Clique no botão ATUALIZAR para poder atualizar o aplicativo'),
                  actions: <Widget>[
                    if (Platform.isAndroid) ...[
                      TextButton(
                        style: TextButton.styleFrom(
                          textStyle: Theme.of(context).textTheme.labelLarge,
                        ),
                        child: const Text('Baixar APK'),
                        onPressed: () async {
                          try {
                            if (await canLaunchUrl(Uri.parse(configProvider.configs?.linkBaixarApk ?? ''))) {
                              await launchUrl(Uri.parse(configProvider.configs?.linkBaixarApk ?? ''));
                            } else {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).removeCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                  content: Text('Não foi possível abrir o LINK, entre em contato com o suporte.'),
                                  backgroundColor: Colors.red,
                                  showCloseIcon: true,
                                ));
                              }
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).removeCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                                content: Text('Não foi possível abrir o LINK, entre em contato com o suporte.'),
                                backgroundColor: Colors.red,
                                showCloseIcon: true,
                              ));
                              // print(e);
                            }
                          }
                        },
                      ),
                    ],
                    TextButton(
                      style: TextButton.styleFrom(
                        textStyle: Theme.of(context).textTheme.labelLarge,
                      ),
                      child: const Text('Atualizar'),
                      onPressed: () async {
                        try {
                          if (Platform.isAndroid) {
                            if (await canLaunchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoAndroid ?? ''))) {
                              await launchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoAndroid ?? ''));
                            }
                          } else if (Platform.isIOS) {
                            if (await canLaunchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoIos ?? ''))) {
                              await launchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoIos ?? ''));
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).removeCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('Não foi possível abrir o LINK, entre em contato com o suporte.'),
                              backgroundColor: Colors.red,
                              showCloseIcon: true,
                            ));
                          }
                        }
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      }
    }
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
    return ListenableBuilder(
        listenable: server,
        builder: (context, snapshot) {
          return ListenableBuilder(
            listenable: configProvider,
            builder: (context, snapshot) {
              return Drawer(
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          UserAccountsDrawerHeader(
                            accountName: Text("#${usuarioProvedor.usuario?.id} ${usuarioProvedor.usuario?.nome}"),
                            accountEmail: Text(usuarioProvedor.usuario?.email ?? ''),
                            currentAccountPicture: const CircleAvatar(
                              child: ClipOval(
                                child: Icon(Icons.person),
                              ),
                            ),
                          ),
                          if (server.hostname.isNotEmpty && server.port > 0)
                            ListTile(
                              leading: server.connected ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.error, color: Colors.red),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (server.nomedopc.isNotEmpty) Text(server.nomedopc),
                                  Text("${server.hostname}:${server.port}"),
                                ],
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
                            leading: const Icon(Icons.system_update),
                            onTap: () async {
                              try {
                                if (Platform.isAndroid) {
                                  if (await canLaunchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoAndroid ?? ''))) {
                                    await launchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoAndroid ?? ''));
                                  }
                                } else if (Platform.isIOS) {
                                  if (await canLaunchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoIos ?? ''))) {
                                    await launchUrl(Uri.parse(configProvider.configs?.linkAtualizacaoIos ?? ''));
                                  }
                                }
                              } catch (e) {
                                if (kDebugMode) {}
                              }
                            },
                            title: const Text('Atualização'),
                          ),
                          if (Platform.isAndroid) ...[
                            ListTile(
                              leading: const Icon(Icons.download),
                              onTap: () async {
                                try {
                                  if (await canLaunchUrl(Uri.parse(configProvider.configs?.linkBaixarApk ?? ''))) {
                                    await launchUrl(Uri.parse(configProvider.configs?.linkBaixarApk ?? ''));
                                  }
                                } catch (e) {
                                  if (kDebugMode) {}
                                }
                              },
                              title: const Text('Baixar APK'),
                            ),
                          ],
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
                    ),
                    const Divider(),
                    Text(
                      "Ultima versão $versaoServidor",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      "Versão instalada $versaoInstalada",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          );
        });
  }
}
