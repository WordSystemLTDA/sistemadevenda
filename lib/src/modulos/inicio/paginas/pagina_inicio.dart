import 'dart:io';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/constantes/funcoes_global.dart';
import 'package:app/src/essencial/provedores/config/config_modelo.dart';
import 'package:app/src/essencial/provedores/config/config_servico.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/shared_prefs/chaves_sharedpreferences.dart';
import 'package:app/src/essencial/widgets/atalhos_pendencias_impressao.dart';
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
  ServicoConfigBigchef servicoConfigBigchef =
      Modular.get<ServicoConfigBigchef>();
  ServicoConfig servicoConfig = Modular.get<ServicoConfig>();
  ModeloConfigBigchef? configBigchef;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    listarDados();
    listarDadosAtualizacoes();
  }

  Future<void> listarDados() async {
    setState(() => isLoading = true);
    try {
      await listarDadosConfigBigChef();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Não foi possível atualizar as configurações.'),
        action:
            SnackBarAction(label: 'Tentar novamente', onPressed: listarDados),
      ));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
    if (!mounted) return;
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

  void verificarAtualizacao(BuildContext context, ConfigModelo versoes) async {
    if (await FuncoesGlobais.appPrecisaAtualizar(
        versoes.versaoAppAndroid, versoes.versaoAppIos)) {
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext contextDialog) {
          return AlertDialog(
            title: const Text(
              'Atualização disponível',
              style: TextStyle(fontSize: 16),
            ),
            content: const Text(
                'Clique no botão ATUALIZAR para poder atualizar o aplicativo'),
            actions: <Widget>[
              TextButton(
                style: TextButton.styleFrom(
                  textStyle: Theme.of(context).textTheme.labelLarge,
                ),
                child: const Text('Atualizar'),
                onPressed: () async {
                  try {
                    if (Platform.isAndroid) {
                      if (await canLaunchUrl(
                          Uri.parse(versoes.linkAtualizacaoAndroid))) {
                        await launchUrl(
                            Uri.parse(versoes.linkAtualizacaoAndroid));
                      }
                    } else if (Platform.isIOS) {
                      if (await canLaunchUrl(
                          Uri.parse(versoes.linkAtualizacaoIos))) {
                        await launchUrl(Uri.parse(versoes.linkAtualizacaoIos));
                      }
                    }
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).removeCurrentSnackBar();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Não foi possível abrir o LINK, entre em contato com o suporte.'),
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
    if (!mounted || conexao == null) return;

    await server.connect(conexao.servidor, conexao.porta).then((sucesso) {
      if (sucesso == false) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text(
                'Canal da cozinha desconectado. A reconexão será automática.'),
            showCloseIcon: true,
            duration: const Duration(seconds: 6),
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

    final escala = MediaQuery.textScalerOf(context);
    final umaColuna = size.width < 360 || escala.scale(17) > 24;
    final itemHeight = 130.0 + escala.scale(17) * 2;

    return ListenableBuilder(
      listenable: context.read<UsuarioProvedor>(),
      builder: (context, snapshot) {
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
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
                if (context
                        .read<UsuarioProvedor>()
                        .usuario
                        ?.nomeEmpresa
                        ?.isNotEmpty ??
                    false)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        context.read<UsuarioProvedor>().usuario!.nomeEmpresa!,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: GridView.count(
                      crossAxisCount:
                          umaColuna ? 1 : (size.width >= 700 ? 3 : 2),
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: itemHeight,
                      children: [
                        CardHome(
                          nome: 'Mesas',
                          cor: const Color(0xFF168575),
                          icone: const Icon(Icons.table_bar_outlined, size: 40),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              settings:
                                  const RouteSettings(name: 'PaginaMesas'),
                              builder: (context) {
                                return const PaginaMesas();
                              },
                            ));
                          },
                        ),
                        CardHome(
                          nome: 'Comandas',
                          cor: const Color(0xFF3478BF),
                          icone:
                              const Icon(Icons.fact_check_outlined, size: 40),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              settings:
                                  const RouteSettings(name: 'PaginaComandas'),
                              builder: (context) {
                                return const PaginaComandas();
                              },
                            ));
                          },
                        ),
                        CardHome(
                          nome: 'Balcão',
                          cor: const Color(0xFF7756A5),
                          icone: const Icon(Icons.shopping_cart_outlined,
                              size: 40),
                          onPressed: () {
                            Navigator.of(context).push(MaterialPageRoute(
                              settings:
                                  const RouteSettings(name: 'PaginaBalcao'),
                              builder: (context) {
                                return const PaginaBalcao();
                              },
                            ));
                          },
                        ),
                        if (configBigchef?.autenticarcomtag == 'Sim')
                          CardHome(
                            nome: 'Comandos NFC',
                            icone: const Icon(Icons.send_to_mobile_outlined,
                                size: 40),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                settings: const RouteSettings(
                                    name: 'PaginaComandosNfc'),
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
                const CartaoPendenciasImpressao(),
              ],
            ),
          ),
        );
      },
    );
  }
}
