import 'dart:io';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/constantes/funcoes_global.dart';
import 'package:app/src/essencial/provedores/config/config_modelo.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/widgets/drawer_customizado.dart';
import 'package:app/src/modulos/balcao/paginas/pagina_balcao.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comandas.dart';
import 'package:app/src/modulos/comandos_nfc/paginas/pagina_comandos_nfc.dart';
import 'package:app/src/modulos/inicio/paginas/widgets/card_home.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_mesas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:url_launcher/url_launcher.dart';

class PaginaInicio extends StatefulWidget {
  const PaginaInicio({super.key});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio> {
  ServicoConfigBigchef servicoConfigBigchef = Modular.get<ServicoConfigBigchef>();
  ServicoConfig servicoConfig = Modular.get<ServicoConfig>();
  ModeloConfigBigchef? configBigchef;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    listarDados();
    listarDadosAtualizacoes();
  }

  void listarDados() async {
    setState(() => isLoading = true);
    await listarDadosConfigBigChef();
    setState(() => isLoading = false);
    await conectarAoServidor();
  }

  Future<void> listarDadosAtualizacoes() async {
    var config = await servicoConfig.listar();

    if (config != null) {
      if (mounted) {
        verificarAtualizacao(context, config);
      }
    }
  }

  void verificarAtualizacao(context, ConfigModelo versoes) async {
    if (await FuncoesGlobais.appPrecisaAtualizar(versoes.versaoAppAndroid, versoes.versaoAppIos)) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext contextDialog) {
          return AlertDialog(
            title: const Text(
              'Atualização disponível',
              style: TextStyle(fontSize: 16),
            ),
            content: const Text('Clique no botão ATUALIZAR para poder atualizar o aplicativo'),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Atualizar'),
                onPressed: () async {
                  try {
                    if (Platform.isAndroid) {
                      if (await canLaunchUrl(Uri.parse(versoes.linkAtualizacaoAndroid))) {
                        await launchUrl(Uri.parse(versoes.linkAtualizacaoAndroid));
                      }
                    } else if (Platform.isIOS) {
                      if (await canLaunchUrl(Uri.parse(versoes.linkAtualizacaoIos))) {
                        await launchUrl(Uri.parse(versoes.linkAtualizacaoIos));
                      }
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Não foi possível abrir o LINK, entre em contato com o suporte.'),
                      backgroundColor: Colors.red,
                      showCloseIcon: true,
                    ));
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> conectarAoServidor() async {
    var server = Modular.get<Server>();

    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();

    await server.connect(conexao!.servidor, conexao.porta).then((sucesso) {
      if (sucesso == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Não foi possível conectar ao servidor ${conexao.servidor}:${conexao.porta}, mude a conexão e a porta e tente novamente'),
            backgroundColor: Colors.red,
            showCloseIcon: true,
            duration: const Duration(hours: 1),
          ));
        }
      }
    });
  }

  Future<void> listarDadosConfigBigChef() async {
    configBigchef = await servicoConfigBigchef.listar();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    final double itemHeight = (size.height - 40) / 4;
    final double itemWidth = size.width / 2;

    return ListenableBuilder(
      listenable: context.read<UsuarioProvedor>(),
      builder: (context, snapshot) {
        return Scaffold(
          drawer: const DrawerCustomizado(),
          appBar: AppBar(
            title: const Text('Início'),
            backgroundColor: Theme.of(context).colorScheme.inversePrimary,
          ),
          body: Visibility(
            visible: isLoading == false,
            replacement: const Center(child: CircularProgressIndicator()),
            child: Column(
              children: [
                Expanded(
                  child: Padding(
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
                              settings: const RouteSettings(name: 'PaginaMesas'),
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
                              settings: const RouteSettings(name: 'PaginaComandas'),
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
                            Navigator.of(context).push(MaterialPageRoute(
                              settings: const RouteSettings(name: 'PaginaBalcao'),
                              builder: (context) {
                                return const PaginaBalcao();
                              },
                            ));
                          },
                        ),
                        if (configBigchef?.autenticarcomtag == 'Sim')
                          CardHome(
                            nome: 'Comandos NFC',
                            icone: const Icon(Icons.send_to_mobile_outlined, size: 40),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                settings: const RouteSettings(name: 'PaginaComandosNfc'),
                                builder: (context) {
                                  return const PaginaComandosNfc();
                                },
                              ));
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
