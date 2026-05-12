import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/widgets/tempo_aberto.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_acompanhar_pedido.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comanda_desocupada.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/pagina_itens_recorrentes.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';

const Color _corAndamento = Color(0xFF22C55E);
const Color _corFechamento = Color(0xFFF59E0B);

class PaginaDetalhesPedido extends StatefulWidget {
  final String? codigoQrcode;
  final String? idComanda;
  final String? idComandaPedido;
  final String? idMesa;
  final bool? abrirModalFecharDireto;
  final TipoCardapio tipo;

  const PaginaDetalhesPedido({
    super.key,
    this.codigoQrcode,
    this.idComanda,
    this.idComandaPedido,
    this.idMesa,
    this.abrirModalFecharDireto,
    required this.tipo,
  });

  @override
  State<PaginaDetalhesPedido> createState() => _PaginaDetalhesPedidoState();
}

class _PaginaDetalhesPedidoState extends State<PaginaDetalhesPedido> with WidgetsBindingObserver {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final Server _server = Modular.get<Server>();

  Modeloworddadoscardapio? dados;
  bool carregando = false;
  String idComanda = '0';
  String idComandaPedido = '0';
  String idMesa = '0';
  String idCliente = '0';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _server.addListener(_aoReceberEventoSocket);
    idComanda = widget.idComanda ?? '0';
    idComandaPedido = widget.idComandaPedido ?? '0';
    idMesa = widget.idMesa ?? '0';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) listarComandasPedidos();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _server.removeListener(_aoReceberEventoSocket);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed && mounted) {
      listarComandasPedidos();
    }
  }

  void _aoReceberEventoSocket() {
    if (!mounted || carregando) return;
    listarComandasPedidos();
  }

  Future<void> listarComandasPedidos() async {
    setState(() => carregando = true);
    await servicoCardapio.listarPorId(widget.idComandaPedido ?? '0', widget.tipo, 'Não', codigoQrcode: widget.codigoQrcode).then((value) {
      dados = value;
      idComanda = value.idComanda ?? '0';
      idComandaPedido = value.id ?? '0';
      idMesa = value.idMesa ?? '0';
    });
    setState(() => carregando = false);
    if (widget.abrirModalFecharDireto == true) fechar();
  }

  Future<bool?> _confirmar({
    required String titulo,
    required String mensagem,
    required Color corAcao,
    required IconData iconeAcao,
    required String labelAcao,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          backgroundColor: cs.surfaceContainerHigh,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: corAcao.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(iconeAcao, color: corAcao, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(titulo, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(mensagem, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: Icon(iconeAcao, size: 18),
                      label: Text(labelAcao),
                      style: FilledButton.styleFrom(
                        backgroundColor: corAcao,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void fechar() async {
    if (dados!.status == 'Fechamento') return;
    final ok = await _confirmar(
      titulo: 'Fechar comanda',
      mensagem: 'Deseja realmente fechar essa comanda? O comprovante de consumo será impresso em seguida.',
      corAcao: Theme.of(context).colorScheme.error,
      iconeAcao: Icons.print_outlined,
      labelAcao: 'Fechar',
    );
    if (ok != true || !mounted) return;

    await servicoCardapio.fecharAbrirComanda(idComandaPedido, 'Fechamento').then((value) async {
      if (!mounted) return;
      if (value.sucesso) {
        Modular.get<Server>().write(jsonEncode({'tipo': widget.tipo.nome}));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.mensagem),
          backgroundColor: value.sucesso ? _corAndamento : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      final duration = DateTime.now().difference(DateTime.parse(dados!.dataAbertura!));
      final newDuration = ConfigSistema.formatarHora(duration);
      Impressao.comprovanteDeConsumo(
        tipodeentrega: dados!.tipodeentrega ?? '',
        valorentrega: dados!.valorentrega ?? '',
        nomeEmpresa: dados!.nomeEmpresa!,
        produtos: dados!.produtos!,
        nomelancamento: dados!.nomelancamento!,
        somaValorHistorico: dados!.somaValorHistorico!,
        celularEmpresa: dados!.celularEmpresa!,
        cnpjEmpresa: dados!.cnpjEmpresa!,
        enderecoEmpresa: dados!.enderecoEmpresa!,
        permanencia: newDuration,
        local: dados!.nome!,
        total: dados!.valorTotal!,
        numeroPedido: dados!.numeroPedido!,
        nomeCliente: (dados!.nomeCliente == '' ? null : dados!.nomeCliente) ?? 'Sem Cliente',
      );
      if (widget.tipo == TipoCardapio.mesa) {
        provedorMesas.listarMesas('');
      } else if (widget.tipo == TipoCardapio.comanda) {
        provedorComanda.listarComandas('');
      }
      await listarComandasPedidos();
    });
  }

  void abrir() async {
    if (dados!.status == 'Andamento') return;
    final ok = await _confirmar(
      titulo: 'Reabrir comanda',
      mensagem: 'Deseja realmente reabrir essa comanda?',
      corAcao: _corAndamento,
      iconeAcao: Icons.lock_open_rounded,
      labelAcao: 'Reabrir',
    );
    if (ok != true || !mounted) return;

    servicoCardapio.fecharAbrirComanda(idComandaPedido, 'Andamento').then((value) {
      if (!mounted) return;
      if (value.sucesso) {
        Modular.get<Server>().write(jsonEncode({'tipo': widget.tipo.nome}));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.mensagem),
          backgroundColor: value.sucesso ? _corAndamento : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      if (widget.tipo == TipoCardapio.mesa) {
        provedorMesas.listarMesas('');
      } else if (widget.tipo == TipoCardapio.comanda) {
        provedorComanda.listarComandas('');
      }
      listarComandasPedidos();
    });
  }

  void _avisoFechamento() {
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Comanda está em status de Fechamento'),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeTipo = widget.tipo.nome;

    if (dados == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          title: Text('Detalhes da $nomeTipo', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (dados!.id == null) {
      return Scaffold(
        backgroundColor: cs.surface,
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          title: Text('Detalhes da $nomeTipo', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.not_listed_location_outlined, size: 56, color: cs.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(
                'Não foi possível encontrar essa $nomeTipo',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    final emFechamento = dados!.status == 'Fechamento';
    final corStatus = emFechamento ? _corFechamento : _corAndamento;
    final labelStatus = emFechamento ? 'Em fechamento' : 'Em andamento';

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Text('Detalhes da $nomeTipo', style: const TextStyle(fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
            children: [
              _CabecalhoComanda(
                nome: dados!.nome ?? '',
                cliente: _resolverCliente(),
                statusLabel: labelStatus,
                corStatus: corStatus,
                numeroPedido: dados!.numeroPedido,
              ),
              const SizedBox(height: 14),
              _AcoesGrid(
                tipo: widget.tipo,
                onAdicionar: () {
                  if (emFechamento) {
                    _avisoFechamento();
                    return;
                  }
                  if (widget.tipo == TipoCardapio.comanda) {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaginaCardapio(
                            tipo: TipoCardapio.comanda,
                            idComanda: dados!.idComanda,
                            idMesa: '0',
                            idCliente: dados!.idCliente!,
                            id: idComandaPedido,
                          ),
                        ));
                  } else {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PaginaCardapio(
                            tipo: TipoCardapio.mesa,
                            idComanda: '0',
                            idMesa: idMesa,
                            idCliente: dados!.idCliente!,
                            id: idComandaPedido,
                          ),
                        ));
                  }
                },
                onItensRecorrentes: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaginaItensRecorrentes(
                          idComanda: idComanda,
                          idComandaPedido: idComandaPedido,
                          idMesa: idMesa,
                          tipo: widget.tipo,
                          idCliente: idCliente,
                        ),
                      ));
                },
                onPedidos: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaginaAcompanharPedido(
                          idComanda: idComanda,
                          idComandaPedido: idComandaPedido,
                          idMesa: idMesa,
                          tipo: widget.tipo,
                        ),
                      ));
                },
                onEditar: () {
                  if (emFechamento) {
                    _avisoFechamento();
                    return;
                  }
                  if (idComanda != '0') {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (context) => PaginaComandaDesocupada(
                        id: idComanda,
                        idComandaPedido: idComandaPedido,
                        nome: dados!.nome!,
                        tipo: widget.tipo,
                      ),
                    ));
                  }
                },
              ),
              const SizedBox(height: 14),
              _PainelConta(
                emFechamento: emFechamento,
                total: dados!.valorTotal ?? '0',
                onFechar: fechar,
                onAbrir: abrir,
              ),
            ],
          ),
          if (carregando)
            Positioned.fill(
              child: ColoredBox(
                color: cs.scrim.withValues(alpha: 0.4),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  String _resolverCliente() {
    if ((dados!.nomeCliente ?? '').isEmpty && (dados!.observacaoDoPedido ?? '').isNotEmpty) {
      return dados!.observacaoDoPedido!;
    }
    if ((dados!.nomeCliente ?? '').isNotEmpty) return dados!.nomeCliente!;
    return 'Sem cliente';
  }
}

class _CabecalhoComanda extends StatelessWidget {
  final String nome;
  final String cliente;
  final String statusLabel;
  final Color corStatus;
  final String? numeroPedido;

  const _CabecalhoComanda({
    required this.nome,
    required this.cliente,
    required this.statusLabel,
    required this.corStatus,
    this.numeroPedido,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: corStatus.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: corStatus,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: corStatus.withValues(alpha: 0.5), blurRadius: 4, spreadRadius: 1)],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        statusLabel,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: corStatus, letterSpacing: 0.3),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (numeroPedido != null && numeroPedido!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$numeroPedido',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onPrimaryContainer),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              nome,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: cs.onSurface),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline_rounded, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    cliente,
                    style: TextStyle(fontSize: 13.5, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.timelapse_rounded, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text('Tempo aberta:', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                const SizedBox(width: 6),
                TempoAberto(
                  textStyle: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: cs.onSurface),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AcoesGrid extends StatelessWidget {
  final TipoCardapio tipo;
  final VoidCallback onAdicionar;
  final VoidCallback onItensRecorrentes;
  final VoidCallback onPedidos;
  final VoidCallback onEditar;

  const _AcoesGrid({
    required this.tipo,
    required this.onAdicionar,
    required this.onItensRecorrentes,
    required this.onPedidos,
    required this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeTipo = tipo.nome;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.40,
      children: [
        _CardAcao(
          icone: Icons.add_circle_outline_rounded,
          titulo: 'Adicionar',
          descricao: 'Lançar itens no pedido',
          cor: cs.primary,
          fundoIcone: cs.primaryContainer,
          corIcone: cs.onPrimaryContainer,
          onTap: onAdicionar,
        ),
        _CardAcao(
          icone: Icons.replay_circle_filled_outlined,
          titulo: 'Itens recorrentes',
          descricao: 'Lançar itens frequentes',
          cor: cs.secondary,
          fundoIcone: cs.secondaryContainer,
          corIcone: cs.onSecondaryContainer,
          onTap: onItensRecorrentes,
        ),
        _CardAcao(
          icone: Icons.shopping_basket_outlined,
          titulo: 'Pedidos',
          descricao: 'Acompanhar pedidos',
          cor: cs.tertiary,
          fundoIcone: cs.tertiaryContainer,
          corIcone: cs.onTertiaryContainer,
          onTap: onPedidos,
        ),
        _CardAcao(
          icone: Icons.edit_outlined,
          titulo: 'Editar $nomeTipo',
          descricao: 'Cliente, mesa, observação',
          cor: cs.primary,
          fundoIcone: cs.primary.withValues(alpha: 0.12),
          corIcone: cs.primary,
          onTap: onEditar,
        ),
      ],
    );
  }
}

class _CardAcao extends StatelessWidget {
  final IconData icone;
  final String titulo;
  final String descricao;
  final Color cor;
  final Color fundoIcone;
  final Color corIcone;
  final VoidCallback onTap;

  const _CardAcao({
    required this.icone,
    required this.titulo,
    required this.descricao,
    required this.cor,
    required this.fundoIcone,
    required this.corIcone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant),
            boxShadow: [
              BoxShadow(color: cs.shadow.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: fundoIcone, borderRadius: BorderRadius.circular(10)),
                child: Icon(icone, size: 22, color: corIcone),
              ),
              const SizedBox(height: 8),
              Text(
                titulo,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.1, color: cs.onSurface),
              ),
              const SizedBox(height: 2),
              Text(
                descricao,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PainelConta extends StatelessWidget {
  final bool emFechamento;
  final String total;
  final VoidCallback onFechar;
  final VoidCallback onAbrir;

  const _PainelConta({
    required this.emFechamento,
    required this.total,
    required this.onFechar,
    required this.onAbrir,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(color: cs.shadow.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.receipt_long_rounded, size: 18, color: cs.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Conta',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cs.onSurfaceVariant, letterSpacing: 1.1),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  double.parse(total).obterReal(),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: _corAndamento,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'total',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _BotaoConta(
                    icone: Icons.print_outlined,
                    label: 'Fechar',
                    cor: cs.error,
                    desabilitado: emFechamento,
                    onTap: onFechar,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _BotaoConta(
                    icone: Icons.lock_open_rounded,
                    label: 'Reabrir',
                    cor: _corAndamento,
                    desabilitado: !emFechamento,
                    onTap: onAbrir,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _BotaoConta extends StatelessWidget {
  final IconData icone;
  final String label;
  final Color cor;
  final bool desabilitado;
  final VoidCallback onTap;

  const _BotaoConta({
    required this.icone,
    required this.label,
    required this.cor,
    required this.desabilitado,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fundo = desabilitado ? cs.surfaceContainerHighest : cor.withValues(alpha: 0.14);
    final corConteudo = desabilitado ? cs.onSurfaceVariant : cor;

    return Material(
      color: fundo,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: desabilitado ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icone, size: 20, color: corConteudo),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: corConteudo, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
