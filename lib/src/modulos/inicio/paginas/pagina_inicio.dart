import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:app/src/modulos/recorrentes/paginas/pagina_recorrentes.dart';

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
import 'package:app/src/modulos/delivery/paginas/pagina_delivery.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comandas.dart';
import 'package:app/src/modulos/comandos_nfc/paginas/pagina_comandos_nfc.dart';
import 'package:app/src/modulos/inicio/paginas/widgets/card_home.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_mesas.dart';
import 'package:app/src/modulos/indicadores/modelo_indicadores.dart';
import 'package:app/src/modulos/indicadores/pagina_indicadores.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class PaginaInicio extends StatefulWidget {
  const PaginaInicio({super.key});

  @override
  State<PaginaInicio> createState() => _PaginaInicioState();
}

class _PaginaInicioState extends State<PaginaInicio>
    with WidgetsBindingObserver {
  ServicoConfigBigchef servicoConfigBigchef =
      Modular.get<ServicoConfigBigchef>();
  ServicoConfig servicoConfig = Modular.get<ServicoConfig>();
  late final Server _server;
  late final UsuarioProvedor _usuarioProvedor;
  late final Listenable _estadoPagina;
  ModeloConfigBigchef? configBigchef;
  Map<String, _UsoAtalhoInicio> _usoAtalhos = const {};
  bool isLoading = true;

  static const _prioridadeInicial = <String>[
    'comandas',
    'delivery',
    'mesas',
    'balcao',
    'recorrentes',
    'comandos_nfc',
    'indicadores',
  ];

  @override
  void initState() {
    super.initState();
    _server = Modular.get<Server>();
    _usuarioProvedor = Modular.get<UsuarioProvedor>();
    _estadoPagina = Listenable.merge([_usuarioProvedor, _server]);
    WidgetsBinding.instance.addObserver(this);
    listarDados();
    listarDadosAtualizacoes();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      listarDadosConfigBigChef().then((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> listarDados() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        listarDadosConfigBigChef(),
        _carregarUsoAtalhos(),
      ]);
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
    final ConfigSharedPreferences config = ConfigSharedPreferences();
    var conexao = await config.getConexao();
    if (!mounted || conexao == null) return;

    await _server.connect(conexao.servidor, conexao.porta).then((sucesso) {
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
    configBigchef = await servicoConfigBigchef.listar(forcarAtualizacao: true);
  }

  String get _chaveUsoAtalhos {
    final usuario = _usuarioProvedor.usuario;
    final identidade = [
      usuario?.empresa,
      usuario?.id,
      usuario?.email?.toLowerCase(),
      usuario?.nome?.toLowerCase(),
    ]
        .whereType<String>()
        .map((valor) => valor.trim())
        .where((valor) => valor.isNotEmpty)
        .join('|');
    final escopo = identidade.isEmpty ? 'usuario-local' : identidade;
    final identificador = base64UrlEncode(utf8.encode(escopo));
    return 'inicio_uso_atalhos_v1_$identificador';
  }

  Future<void> _carregarUsoAtalhos() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final salvo = prefs.getString(_chaveUsoAtalhos);
      if (salvo == null || salvo.isEmpty) {
        _usoAtalhos = const {};
        return;
      }

      final dados = jsonDecode(salvo);
      if (dados is! Map) {
        _usoAtalhos = const {};
        return;
      }

      _usoAtalhos = {
        for (final entrada in dados.entries)
          if (entrada.key is String && entrada.value is Map)
            entrada.key as String: _UsoAtalhoInicio.fromJson(
              Map<String, dynamic>.from(entrada.value as Map),
            ),
      };
    } catch (_) {
      _usoAtalhos = const {};
    }
  }

  Future<void> _registrarUsoAtalho(String identificador) async {
    final agora = DateTime.now().millisecondsSinceEpoch;
    final usoAtual = _usoAtalhos[identificador];
    final usosAtualizados = Map<String, _UsoAtalhoInicio>.from(_usoAtalhos)
      ..[identificador] = _UsoAtalhoInicio(
        quantidade: (usoAtual?.quantidade ?? 0) + 1,
        ultimoUso: agora,
      );

    if (mounted) {
      setState(() => _usoAtalhos = usosAtualizados);
    } else {
      _usoAtalhos = usosAtualizados;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _chaveUsoAtalhos,
        jsonEncode({
          for (final entrada in usosAtualizados.entries)
            entrada.key: entrada.value.toJson(),
        }),
      );
    } catch (_) {
      // A ordenação continua válida durante a sessão se o armazenamento falhar.
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _estadoPagina,
      builder: (context, _) {
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final escuro = theme.brightness == Brightness.dark;
        final media = MediaQuery.of(context);
        final nomeEmpresa = _nomeApresentacao(
          _usuarioProvedor.usuario?.nomeEmpresa ?? '',
        );
        final statusCompacto =
            media.size.width < 370 || media.textScaler.scale(11) > 16;

        return Scaffold(
          backgroundColor: escuro ? cs.surface : const Color(0xFFF4F8FB),
          drawer: const DrawerCustomizado(),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            toolbarHeight: 64,
            leadingWidth: 56,
            leading: Builder(
              builder: (context) => IconButton(
                tooltip: 'Abrir menu',
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: const Icon(Icons.menu_rounded),
                color: cs.onSurfaceVariant,
              ),
            ),
            titleSpacing: 0,
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: escuro ? cs.surface : const Color(0xFFF4F8FB),
            title: _MarcaEmpresa(nome: _nomeCurto(nomeEmpresa)),
            actions: [
              _StatusConexao(
                online: _server.connected,
                compacto: statusCompacto,
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Divider(
                height: 1,
                thickness: 1,
                color: cs.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _conteudoInicio(context, nomeEmpresa),
              ),
              const CartaoPendenciasImpressao(estiloInicio: true),
            ],
          ),
        );
      },
    );
  }

  Widget _conteudoInicio(BuildContext context, String nomeEmpresa) {
    final escala = MediaQuery.textScalerOf(context);
    final mostrarRecorrentes = configBigchef?.recorrentesHabilitados == true;
    final mostrarIndicadores = podeVerIndicadores(_usuarioProvedor.usuario);
    final mostrarNfc = configBigchef?.autenticarcomtag == 'Sim';

    return RefreshIndicator(
      onRefresh: listarDados,
      child: LayoutBuilder(
        builder: (context, _) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 26, 16, 28),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: LayoutBuilder(
                  builder: (context, limites) {
                    final largura = limites.maxWidth;
                    final tablet = largura >= 600;
                    final empilhar = largura < 330 || escala.scale(16) > 25;
                    final alturaEmpilhadaCalculada = 51 +
                        escala.scale(19) * 1.1 +
                        escala.scale(12) * 1.2 +
                        47;
                    final alturaEmpilhada = alturaEmpilhadaCalculada < 142
                        ? 142.0
                        : alturaEmpilhadaCalculada;
                    final alturaPrincipal = tablet
                        ? 208.0
                        : empilhar
                            ? alturaEmpilhada
                            : 176.0;
                    final alturaSecundaria = tablet
                        ? 208.0
                        : empilhar
                            ? alturaEmpilhada
                            : 146.0;
                    final alturaAtalhoCalculada =
                        28 + escala.scale(14) + escala.scale(11) + 4;
                    final alturaAtalho = alturaAtalhoCalculada < 68
                        ? 68.0
                        : alturaAtalhoCalculada;

                    final acoes = _ordenarAtalhos([
                      _AtalhoInicio(
                        identificador: 'comandas',
                        nome: 'Comandas',
                        descricao: 'Pedidos abertos',
                        icone: Icons.assignment_outlined,
                        cor: const Color(0xFFEF6956),
                        onPressed: () => _abrirAtalho(
                          context,
                          'comandas',
                          const PaginaComandas(),
                          'PaginaComandas',
                        ),
                      ),
                      _AtalhoInicio(
                        identificador: 'delivery',
                        nome: 'Delivery',
                        descricao: 'Novo pedido',
                        icone: Icons.delivery_dining_outlined,
                        cor: const Color(0xFF347DB5),
                        onPressed: () => _abrirAtalho(
                          context,
                          'delivery',
                          const PaginaDelivery(),
                          'PaginaDelivery',
                        ),
                      ),
                      _AtalhoInicio(
                        identificador: 'mesas',
                        nome: 'Mesas',
                        descricao: 'Ver mapa do salão',
                        icone: Icons.restaurant_rounded,
                        cor: const Color(0xFF0D455D),
                        onPressed: () => _abrirAtalho(
                          context,
                          'mesas',
                          const PaginaMesas(),
                          'PaginaMesas',
                        ),
                      ),
                      _AtalhoInicio(
                        identificador: 'balcao',
                        nome: 'Balcão',
                        descricao: 'Venda rápida',
                        icone: Icons.receipt_long_outlined,
                        cor: const Color(0xFF2189A4),
                        onPressed: () => _abrirAtalho(
                          context,
                          'balcao',
                          const PaginaBalcao(),
                          'PaginaBalcao',
                        ),
                      ),
                      if (mostrarRecorrentes)
                        _AtalhoInicio(
                          identificador: 'recorrentes',
                          nome: 'Recorrentes',
                          descricao: 'Programados',
                          icone: Icons.event_repeat_rounded,
                          cor: const Color(0xFF70579B),
                          onPressed: () => _abrirAtalho(
                            context,
                            'recorrentes',
                            const PaginaRecorrentes(),
                            'PaginaRecorrentes',
                          ),
                        ),
                      if (mostrarNfc)
                        _AtalhoInicio(
                          identificador: 'comandos_nfc',
                          nome: 'Comandos NFC',
                          descricao: 'Ações por aproximação',
                          icone: Icons.send_to_mobile_outlined,
                          cor: const Color(0xFF536A99),
                          onPressed: () => _abrirAtalho(
                            context,
                            'comandos_nfc',
                            const PaginaComandosNfc(),
                            'PaginaComandosNfc',
                          ),
                        ),
                      if (mostrarIndicadores)
                        _AtalhoInicio(
                          identificador: 'indicadores',
                          nome: 'Indicadores',
                          descricao: 'Acompanhe o desempenho do restaurante',
                          icone: Icons.bar_chart_rounded,
                          cor: const Color(0xFF356D85),
                          mostrarSeta: true,
                          onPressed: () => _abrirAtalho(
                            context,
                            'indicadores',
                            const PaginaIndicadores(),
                            'PaginaIndicadores',
                          ),
                        ),
                    ]);
                    final principal = _cardDestaque(acoes[0], decorado: true);
                    final secundario = _cardDestaque(acoes[1]);
                    final terciario = _cardDestaque(acoes[2]);
                    final atalhos = acoes.skip(3).toList(growable: false);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nomeEmpresa,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFEF6956),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Pronto para atender?',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Theme.of(context).colorScheme.onSurface
                                    : const Color(0xFF123F53),
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Escolha uma área para começar.',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                        ),
                        const SizedBox(height: 28),
                        if (tablet) ...[
                          SizedBox(
                            height: alturaPrincipal,
                            child: Row(
                              children: [
                                Expanded(child: principal),
                                const SizedBox(width: 12),
                                Expanded(child: secundario),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: (largura - 12) / 2,
                            height: alturaSecundaria,
                            child: terciario,
                          ),
                        ] else ...[
                          SizedBox(
                            width: double.infinity,
                            height: alturaPrincipal,
                            child: principal,
                          ),
                          const SizedBox(height: 12),
                          if (empilhar)
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: alturaSecundaria,
                                  child: secundario,
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: alturaSecundaria,
                                  child: terciario,
                                ),
                              ],
                            )
                          else
                            SizedBox(
                              height: alturaSecundaria,
                              child: Row(
                                children: [
                                  Expanded(child: secundario),
                                  const SizedBox(width: 12),
                                  Expanded(child: terciario),
                                ],
                              ),
                            ),
                        ],
                        const SizedBox(height: 14),
                        _gradeAtalhos(
                          atalhos,
                          empilhar: empilhar,
                          altura: alturaAtalho,
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _gradeAtalhos(
    List<_AtalhoInicio> atalhos, {
    required bool empilhar,
    required double altura,
  }) {
    return LayoutBuilder(
      builder: (context, limites) {
        final larguraMetade = (limites.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var indice = 0; indice < atalhos.length; indice++)
              SizedBox(
                width: empilhar ||
                        atalhos.length == 1 ||
                        (atalhos.length.isOdd && indice == atalhos.length - 1)
                    ? limites.maxWidth
                    : larguraMetade,
                height: altura,
                child: CardAtalhoHome(
                  nome: atalhos[indice].nome,
                  descricao: atalhos[indice].descricao,
                  icone: atalhos[indice].icone,
                  onPressed: atalhos[indice].onPressed,
                  mostrarSeta: atalhos[indice].mostrarSeta,
                ),
              ),
          ],
        );
      },
    );
  }

  CardHome _cardDestaque(
    _AtalhoInicio atalho, {
    bool decorado = false,
  }) {
    return CardHome(
      nome: atalho.nome,
      descricao: atalho.descricao,
      icone: atalho.icone,
      cor: atalho.cor,
      decorado: decorado,
      onPressed: atalho.onPressed,
    );
  }

  List<_AtalhoInicio> _ordenarAtalhos(List<_AtalhoInicio> atalhos) {
    final ordenados = List<_AtalhoInicio>.from(atalhos);
    ordenados.sort((primeiro, segundo) {
      final usoPrimeiro = _usoAtalhos[primeiro.identificador];
      final usoSegundo = _usoAtalhos[segundo.identificador];
      final porQuantidade =
          (usoSegundo?.quantidade ?? 0).compareTo(usoPrimeiro?.quantidade ?? 0);
      if (porQuantidade != 0) return porQuantidade;

      final porUltimoUso =
          (usoSegundo?.ultimoUso ?? 0).compareTo(usoPrimeiro?.ultimoUso ?? 0);
      if (porUltimoUso != 0) return porUltimoUso;

      return _prioridadeInicial
          .indexOf(primeiro.identificador)
          .compareTo(_prioridadeInicial.indexOf(segundo.identificador));
    });
    return ordenados;
  }

  void _abrirAtalho(
    BuildContext context,
    String identificador,
    Widget pagina,
    String nomeRota,
  ) {
    unawaited(_registrarUsoAtalho(identificador));
    _abrirPagina(context, pagina, nomeRota);
  }

  void _abrirPagina(BuildContext context, Widget pagina, String nomeRota) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: nomeRota),
        builder: (_) => pagina,
      ),
    );
  }
}

class _AtalhoInicio {
  const _AtalhoInicio({
    required this.identificador,
    required this.nome,
    required this.descricao,
    required this.icone,
    required this.cor,
    required this.onPressed,
    this.mostrarSeta = false,
  });

  final String identificador;
  final String nome;
  final String descricao;
  final IconData icone;
  final Color cor;
  final VoidCallback onPressed;
  final bool mostrarSeta;
}

class _UsoAtalhoInicio {
  const _UsoAtalhoInicio({
    required this.quantidade,
    required this.ultimoUso,
  });

  final int quantidade;
  final int ultimoUso;

  factory _UsoAtalhoInicio.fromJson(Map<String, dynamic> json) {
    return _UsoAtalhoInicio(
      quantidade: (json['quantidade'] as num?)?.toInt() ?? 0,
      ultimoUso: (json['ultimoUso'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, int> toJson() => {
        'quantidade': quantidade,
        'ultimoUso': ultimoUso,
      };
}

class _MarcaEmpresa extends StatelessWidget {
  const _MarcaEmpresa({required this.nome});

  final String nome;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final escuro = Theme.of(context).brightness == Brightness.dark;
    final corPrincipal = escuro ? cs.onSurface : const Color(0xFF123F53);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF123F53),
          ),
          child: const Icon(Icons.restaurant_rounded,
              size: 19, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nome.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: corPrincipal,
                  fontSize: 12,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.15,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Atendimento',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                  height: 1,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusConexao extends StatelessWidget {
  const _StatusConexao({required this.online, required this.compacto});

  final bool online;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final cor = online ? const Color(0xFF188653) : const Color(0xFFB35C12);
    final fundo = online ? const Color(0xFFE9F7EF) : const Color(0xFFFFF2E5);
    final texto = online ? 'Online' : 'Offline';

    return Tooltip(
      message: texto,
      child: Semantics(
        label: 'Canal da cozinha $texto',
        child: Container(
          key: const ValueKey('status-conexao-inicio'),
          constraints: const BoxConstraints(minHeight: 30, minWidth: 30),
          padding:
              EdgeInsets.symmetric(horizontal: compacto ? 10 : 11, vertical: 7),
          decoration: BoxDecoration(
            color: fundo,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: cor.withValues(alpha: 0.22)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(shape: BoxShape.circle, color: cor),
              ),
              if (!compacto) ...[
                const SizedBox(width: 6),
                Text(
                  texto,
                  style: TextStyle(
                    color: cor,
                    fontSize: 10,
                    height: 1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _nomeApresentacao(String nome) {
  final limpo = nome.trim();
  if (limpo.isEmpty) return 'Seu estabelecimento';
  if (limpo != limpo.toUpperCase()) return limpo;

  const conectivos = {'da', 'das', 'de', 'do', 'dos', 'e'};
  return limpo.split(RegExp(r'\s+')).map((palavra) {
    final minuscula = palavra.toLowerCase();
    if (conectivos.contains(minuscula)) return minuscula;
    return '${minuscula[0].toUpperCase()}${minuscula.substring(1)}';
  }).join(' ');
}

String _nomeCurto(String nome) {
  final palavras = nome.trim().split(RegExp(r'\s+'));
  const segmentos = {
    'pizzaria',
    'restaurante',
    'lanchonete',
    'padaria',
    'bar',
  };
  if (palavras.length > 1 && segmentos.contains(palavras.first.toLowerCase())) {
    return palavras.skip(1).join(' ');
  }
  return nome;
}
