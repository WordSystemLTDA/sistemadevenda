import 'dart:async';

import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/modelos/modelo_config_bigchef.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/widgets/qrcode_scanner_com_overlay.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_detalhes_pedidos.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/paginas/todas_comandas.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/card_comanda.dart';
import 'package:app/src/modulos/comandas/paginas/widgets/modal_digitar_codigo.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class PaginaComandas extends StatefulWidget {
  const PaginaComandas({super.key});

  @override
  State<PaginaComandas> createState() => _PaginaComandasState();
}

class _PaginaComandasState extends State<PaginaComandas> {
  ServicoConfigBigchef servicoConfigBigchef = Modular.get<ServicoConfigBigchef>();
  final MobileScannerController controller = MobileScannerController();
  UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  TextEditingController pesquisaController = TextEditingController();

  Timer? debounce;
  Timer? _debounce;

  final ProvedorComanda provedor = Modular.get<ProvedorComanda>();
  bool isLoading = true;
  Timer? _timer;
  String opcaoFiltro = 'Ocupadas';
  bool nfcDisponivel = true;
  ModeloConfigBigchef? configBigchef;

  @override
  void initState() {
    super.initState();
    listarComandas();
  }

  void listarComandas() async {
    configBigchef = await servicoConfigBigchef.listar();
    nfcDisponivel = await FlutterNfcKit.nfcAvailability == NFCAvailability.available;

    setState(() => isLoading = true);
    await provedor.listarComandas('');
    setState(() => isLoading = false);

    if (configBigchef?.autenticarcomtag == 'Sim' && await FlutterNfcKit.nfcAvailability == NFCAvailability.available) {
      await nfc();
    }
  }

  Future<void> nfc() async {
    FlutterNfcKit.finish();

    try {
      var tag = await FlutterNfcKit.poll(
        timeout: const Duration(seconds: 10),
        iosMultipleTagMessage: "Multiplas TAGS Encontradas!",
        iosAlertMessage: "Escaneie a sua TAG",
        readIso14443A: true,
      );

      if (tag.type == NFCTagType.mifare_ultralight) {
        var ndef = await FlutterNfcKit.readNDEFRecords();
        if (ndef.isEmpty) {
          FlutterNfcKit.finish(iosErrorMessage: 'Essa TAG não tem código Registrado.');
          return;
        }

        var payload = ndef.first.toString();
        var dataText = payload.indexOf('text=');
        var codigo = payload.substring(dataText + 5);

        final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();

        await servicoCardapio.listarIdCodigoQrcode(TipoCardapio.comanda, codigo).then((value) {
          if (value.sucesso == false) {
            FlutterNfcKit.finish(iosErrorMessage: 'Essa comanda não existe.');
            return;
          } else {
            FlutterNfcKit.finish();
          }

          if (value.ocupado == true) {
            if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '1') {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaginaDetalhesPedido(
                      idComandaPedido: value.idComandaPedido,
                      idComanda: value.id,
                      tipo: TipoCardapio.comanda,
                    ),
                  ),
                );
              }
            } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '2') {
              if (mounted) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PaginaDetalhesPedido(
                      idComandaPedido: value.idComandaPedido,
                      idComanda: value.id,
                      tipo: TipoCardapio.comanda,
                      abrirModalFecharDireto: true,
                    ),
                  ),
                );
              }
            } else if (usuarioProvedor.usuario?.configuracoes?.modaladdcomanda == '3') {
              if (value.fechamento == true) {
                if (mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PaginaDetalhesPedido(
                        idComandaPedido: value.idComandaPedido,
                        idComanda: value.id,
                        tipo: TipoCardapio.comanda,
                      ),
                    ),
                  );
                }
                return;
              }

              if (mounted) {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return PaginaCardapio(
                      tipo: TipoCardapio.comanda,
                      idComanda: value.id,
                      idMesa: '0',
                      idCliente: value.idCliente,
                      id: value.idComandaPedido,
                    );
                  },
                ));
              }
            }
          } else {
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => PaginaComandaDesocupada(
                    id: value.id,
                    nome: value.nome,
                    tipo: TipoCardapio.comanda,
                  ),
                ),
              );
            }
          }
        });
      } else {
        FlutterNfcKit.finish(iosErrorMessage: 'Tipo de TAG não reconhecido: ${tag.type.name}');
        return;
      }
    } on PlatformException catch (e) {
      FlutterNfcKit.finish(iosErrorMessage: e.details);
    }
  }

  @override
  void dispose() {
    if (_timer != null) _timer!.cancel();
    if (debounce != null) debounce?.cancel();
    if (_debounce != null) _debounce?.cancel();
    super.dispose();
  }

  int _totalGeral() {
    return provedor.comandas.fold(0, (p, e) => p + (e.comandas?.length ?? 0));
  }

  int _totalOcupadas() {
    return provedor.comandas.where((g) => (g.comandas ?? []).any((c) => c.comandaOcupada == true)).fold(0, (p, e) => p + ((e.comandas ?? []).where((c) => c.comandaOcupada).length));
  }

  int _totalLivres() {
    return provedor.comandas.where((g) => (g.comandas ?? []).any((c) => c.comandaOcupada == false)).fold(0, (p, e) => p + ((e.comandas ?? []).where((c) => !c.comandaOcupada).length));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corFundo = isDark ? const Color(0xFF111827) : const Color(0xFFF6F7F9);

    return Scaffold(
      backgroundColor: corFundo,
      appBar: AppBar(
        title: const Text('Comandas', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        elevation: 0,
        actions: [
          MenuAnchor(
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(isDark ? const Color(0xFF1F2937) : Colors.white),
              elevation: const WidgetStatePropertyAll(6),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            builder: (BuildContext context, MenuController controller, Widget? child) {
              return IconButton(
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
                icon: const Icon(Icons.more_horiz),
              );
            },
            menuChildren: [
              MenuItemButton(
                leadingIcon: const Icon(Icons.list_alt_rounded, size: 20, color: Color(0xFF3B82F6)),
                onPressed: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (context) => const TodasComandas()));
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('Todas as comandas'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: provedor,
        builder: (context, child) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final tabsLength = (provedor.comandas.isNotEmpty ? (provedor.comandas.length + 1) : 1) - (provedor.comandas.where((element) => (element.comandas ?? []).where((element2) => element2.comandaOcupada == true && element.titulo == 'em Fechamento').isNotEmpty).isNotEmpty ? 1 : 0);

          return DefaultTabController(
            length: tabsLength,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CabecalhoBusca(
                  pesquisaController: pesquisaController,
                  onChanged: (_) => setState(() {}),
                  onAbrirModalCodigo: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      showDragHandle: false,
                      builder: (context) {
                        return GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const ModalDigitarCodigo(tipo: TipoCardapio.comanda),
                        );
                      },
                    );
                  },
                  onAbrirScanner: () {
                    Navigator.push(context, MaterialPageRoute(
                      builder: (context) {
                        return const BarcodeScannerWithOverlay(tipo: TipoCardapio.comanda);
                      },
                    ));
                  },
                  onNfc: configBigchef?.autenticarcomtag == 'Sim' && nfcDisponivel ? () async => await nfc() : null,
                ),
                _BarraAbas(
                  total: _totalGeral(),
                  ocupadas: _totalOcupadas(),
                  livres: _totalLivres(),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ListaTab(
                        onRefresh: () async => listarComandas(),
                        child: _conteudoLista(
                          modo: _ModoLista.todas,
                          pesquisa: pesquisaController.text,
                        ),
                      ),
                      _ListaTab(
                        onRefresh: () async => listarComandas(),
                        child: _conteudoLista(
                          modo: _ModoLista.ocupadas,
                          pesquisa: pesquisaController.text,
                        ),
                      ),
                      _ListaTab(
                        onRefresh: () async => listarComandas(),
                        child: _conteudoLista(
                          modo: _ModoLista.livres,
                          pesquisa: pesquisaController.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _conteudoLista({required _ModoLista modo, required String pesquisa}) {
    final pesquisaLower = pesquisa.toLowerCase();

    final gruposBase = provedor.comandas.where((g) {
      if (modo == _ModoLista.ocupadas) {
        return (g.comandas ?? []).any((c) => c.comandaOcupada == true);
      } else if (modo == _ModoLista.livres) {
        return (g.comandas ?? []).any((c) => c.comandaOcupada == false);
      }
      return true;
    }).toList();

    final grupos = gruposBase
        .map((g) {
          final filtradas = (g.comandas ?? []).where((c) {
            if (modo == _ModoLista.ocupadas && !c.comandaOcupada) return false;
            if (modo == _ModoLista.livres && c.comandaOcupada) return false;
            if (pesquisaLower.isEmpty) return true;
            return (c.nomeCliente ?? '').toLowerCase().contains(pesquisaLower) || (c.obs ?? '').toLowerCase().contains(pesquisaLower) || c.nome.toLowerCase().contains(pesquisaLower);
          }).toList();
          return (titulo: g.titulo, itens: filtradas);
        })
        .where((g) => g.itens.isNotEmpty)
        .toList();

    if (grupos.isEmpty) {
      return const _EstadoVazio(
        icone: Icons.inbox_outlined,
        titulo: 'Nada por aqui',
        subtitulo: 'Nenhuma comanda encontrada com os filtros atuais.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: grupos.length,
      itemBuilder: (context, index) {
        final grupo = grupos[index];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CabecalhoSecao(titulo: grupo.titulo, quantidade: grupo.itens.length),
            const SizedBox(height: 6),
            ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              itemCount: grupo.itens.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) => CardComanda(itemComanda: grupo.itens[i]),
            ),
            const SizedBox(height: 14),
          ],
        );
      },
    );
  }
}

enum _ModoLista { todas, ocupadas, livres }

class _CabecalhoBusca extends StatelessWidget {
  final TextEditingController pesquisaController;
  final ValueChanged<String> onChanged;
  final VoidCallback onAbrirModalCodigo;
  final VoidCallback onAbrirScanner;
  final VoidCallback? onNfc;

  const _CabecalhoBusca({
    required this.pesquisaController,
    required this.onChanged,
    required this.onAbrirModalCodigo,
    required this.onAbrirScanner,
    this.onNfc,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final corCampo = isDark ? const Color(0xFF1F2937) : Colors.white;
    final corBorda = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE5E7EB);
    final corIcone = isDark ? Colors.grey[300] : const Color(0xFF374151);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: corCampo,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: corBorda),
              ),
              child: TextField(
                controller: pesquisaController,
                onChanged: onChanged,
                textAlignVertical: TextAlignVertical.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Buscar por nome, cliente ou observação',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: corIcone),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _BotaoAcao(
            icone: Icons.keyboard_alt_outlined,
            cor: const Color(0xFF6366F1),
            tooltip: 'Digitar código',
            onTap: onAbrirModalCodigo,
          ),
          const SizedBox(width: 8),
          _BotaoAcao(
            icone: Icons.qr_code_scanner_rounded,
            cor: const Color(0xFF3B82F6),
            tooltip: 'Escanear QR Code',
            onTap: onAbrirScanner,
          ),
          if (onNfc != null) ...[
            const SizedBox(width: 8),
            _BotaoAcao(
              icone: Icons.nfc_rounded,
              cor: const Color(0xFF10B981),
              tooltip: 'Ler tag NFC',
              onTap: onNfc!,
            ),
          ],
        ],
      ),
    );
  }
}

class _BotaoAcao extends StatelessWidget {
  final IconData icone;
  final Color cor;
  final String tooltip;
  final VoidCallback onTap;

  const _BotaoAcao({
    required this.icone,
    required this.cor,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icone, color: cor, size: 22),
          ),
        ),
      ),
    );
  }
}

class _BarraAbas extends StatelessWidget {
  final int total;
  final int ocupadas;
  final int livres;
  const _BarraAbas({required this.total, required this.ocupadas, required this.livres});

  @override
  Widget build(BuildContext context) {
    return TabBar(
      tabs: [
        Tab(text: 'Todas · $total'),
        Tab(text: 'Ocupadas · $ocupadas'),
        Tab(text: 'Livres · $livres'),
      ],
    );
  }
}

class _ListaTab extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;
  const _ListaTab({required this.onRefresh, required this.child});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: child,
    );
  }
}

class _CabecalhoSecao extends StatelessWidget {
  final String titulo;
  final int quantidade;
  const _CabecalhoSecao({required this.titulo, required this.quantidade});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cor = isDark ? Colors.grey[300] : const Color(0xFF374151);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            titulo,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cor,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$quantidade',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : const Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String subtitulo;
  const _EstadoVazio({required this.icone, required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        Icon(icone, size: 56, color: Colors.grey[400]),
        const SizedBox(height: 12),
        Text(
          titulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          subtitulo,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
        ),
      ],
    );
  }
}
