import 'dart:convert';
import 'package:app/src/modulos/transferencias/servico_transferencias.dart';
import 'package:app/src/modulos/transferencias/transferencia_atendimento.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';

import 'package:app/src/app_widget.dart';
import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/essencial/widgets/badge_valor_oculto.dart';
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

class _PaginaDetalhesPedidoState extends State<PaginaDetalhesPedido>
    with WidgetsBindingObserver {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final Server _server = Modular.get<Server>();

  Modeloworddadoscardapio? dados;
  bool carregando = false;
  bool _reimprimindoPreparo = false;
  String? erroConsulta;
  bool _fechamentoDiretoExibido = false;
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
    if (!mounted || carregando || _reimprimindoPreparo) return;
    listarComandasPedidos();
  }

  Future<void> listarComandasPedidos() async {
    if (!mounted || carregando) return;
    setState(() => carregando = true);
    try {
      final value = await servicoCardapio.listarPorId(
          widget.idComandaPedido ?? '0', widget.tipo, 'Não',
          codigoQrcode: widget.codigoQrcode);
      if (!mounted) return;
      erroConsulta = null;
      dados = value;
      idComanda = value.idComanda ?? '0';
      idComandaPedido = value.id ?? '0';
      idMesa = value.idMesa ?? '0';
      idCliente = value.idCliente ?? '0';
    } catch (_) {
      if (!mounted) return;
      erroConsulta = 'Não foi possível atualizar o atendimento.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(erroConsulta!),
        action: SnackBarAction(
            label: 'Tentar novamente', onPressed: listarComandasPedidos),
      ));
    } finally {
      if (mounted) setState(() => carregando = false);
    }
    if (!mounted) return;
    if (erroConsulta == null &&
        dados?.id != null &&
        widget.abrirModalFecharDireto == true &&
        !_fechamentoDiretoExibido) {
      _fechamentoDiretoExibido = true;
      fechar();
    }
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
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
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
                      child: Text(titulo,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(mensagem,
                    style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
                const SizedBox(height: 22),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton.icon(
                      onPressed: () => Navigator.pop(ctx, true),
                      icon: Icon(iconeAcao, size: 18),
                      label: Text(labelAcao),
                      style: FilledButton.styleFrom(
                        backgroundColor: corAcao,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
      titulo: 'Fechar ${widget.tipo.nome.toLowerCase()}',
      mensagem:
          'Deseja realmente fechar essa ${widget.tipo.nome.toLowerCase()}? O comprovante de consumo será impresso em seguida.',
      corAcao: Theme.of(context).colorScheme.error,
      iconeAcao: Icons.print_outlined,
      labelAcao: 'Fechar',
    );
    if (ok != true || !mounted) return;

    await servicoCardapio
        .fecharAbrirComanda(idComandaPedido, 'Fechamento')
        .then((value) async {
      if (!mounted) return;
      if (value.sucesso) {
        Modular.get<Server>().write(jsonEncode({'tipo': widget.tipo.nome}));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.mensagem),
          backgroundColor: value.sucesso
              ? _corAndamento
              : Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      if (!value.sucesso) return;
      final abertura = DateTime.tryParse(dados!.dataAbertura ?? '');
      final newDuration = abertura == null
          ? ''
          : ConfigSistema.formatarHora(DateTime.now().difference(abertura));
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
        nomeCliente: (dados!.nomeCliente == '' ? null : dados!.nomeCliente) ??
            'Sem Cliente',
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
      titulo: 'Reabrir ${widget.tipo.nome.toLowerCase()}',
      mensagem:
          'Deseja realmente reabrir essa ${widget.tipo.nome.toLowerCase()}?',
      corAcao: _corAndamento,
      iconeAcao: Icons.lock_open_rounded,
      labelAcao: 'Reabrir',
    );
    if (ok != true || !mounted) return;

    servicoCardapio
        .fecharAbrirComanda(idComandaPedido, 'Andamento')
        .then((value) {
      if (!mounted) return;
      if (value.sucesso) {
        Modular.get<Server>().write(jsonEncode({'tipo': widget.tipo.nome}));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value.mensagem),
          backgroundColor: value.sucesso
              ? _corAndamento
              : Theme.of(context).colorScheme.error,
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

  Future<void> _reimprimirComprovantePreparo() async {
    if (_reimprimindoPreparo || carregando) return;

    final nomeTipo = widget.tipo.nome.toLowerCase();
    final ok = await _confirmar(
      titulo: 'Reimprimir comprovante de preparo',
      mensagem:
          'Todos os itens atuais da $nomeTipo serão enviados novamente para preparo. Deseja continuar?',
      corAcao: Theme.of(context).colorScheme.primary,
      iconeAcao: Icons.print_outlined,
      labelAcao: 'Reimprimir',
    );
    if (ok != true || !mounted) return;

    setState(() => _reimprimindoPreparo = true);
    var mensagem = 'Não foi possível reimprimir o comprovante de preparo.';
    var sucesso = false;
    try {
      final atendimento = await servicoCardapio.listarPorId(
        idComandaPedido,
        widget.tipo,
        'Sim',
        codigoQrcode: widget.codigoQrcode,
      );
      final produtos = atendimento.produtos ?? [];
      if (atendimento.id == null || atendimento.id != idComandaPedido) {
        mensagem = 'Não foi possível confirmar os dados deste atendimento.';
      } else if (produtos.isEmpty) {
        mensagem = 'Não há itens para reimprimir neste atendimento.';
      } else {
        final impressoes = Impressao.prepararComprovanteDePedido(
          produtos: produtos,
          tipoTela: widget.tipo,
          tipodeentrega: atendimento.tipodeentrega ?? '',
          comanda:
              'REIMPRESSÃO - ${atendimento.nome ?? dados!.nome ?? widget.tipo.nome}',
          numeroPedido: atendimento.numeroPedido ?? dados!.numeroPedido ?? '',
          nomeCliente: nomeClienteAtendimento(
            atendimento.nomeCliente,
            atendimento.observacaoDoPedido,
            vazio: '',
          ),
          nomeEmpresa: atendimento.nomeEmpresa ?? dados!.nomeEmpresa ?? '',
          local: widget.tipo == TipoCardapio.mesa
              ? ''
              : atendimento.nomeMesa ?? dados!.nomeMesa ?? '',
        );
        if (impressoes.isEmpty) {
          mensagem =
              'Nenhum item possui uma impressora de preparo configurada.';
        } else {
          await _server.enviarImpressoes(impressoes);
          mensagem = 'Reimpressão do comprovante de preparo solicitada.';
          sucesso = true;
        }
      }
    } catch (_) {
      mensagem = 'Não foi possível reimprimir o comprovante de preparo.';
    } finally {
      if (mounted) setState(() => _reimprimindoPreparo = false);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(mensagem),
        backgroundColor:
            sucesso ? _corAndamento : Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final nomeTipo = widget.tipo.nome;

    if (dados == null) {
      return Scaffold(
        backgroundColor: VisualAtendimento.superficie(context),
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          title: Text('Detalhes da $nomeTipo',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: Center(
            child: erroConsulta == null || carregando
                ? const CircularProgressIndicator()
                : Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(erroConsulta!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                          onPressed: listarComandasPedidos,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tentar novamente')),
                    ]))),
      );
    }

    if (dados!.id == null) {
      return Scaffold(
        backgroundColor: VisualAtendimento.superficie(context),
        appBar: AppBar(
          backgroundColor: cs.inversePrimary,
          title: Text('Detalhes da $nomeTipo',
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.not_listed_location_outlined,
                  size: 56, color: cs.onSurfaceVariant),
              const SizedBox(height: 14),
              Text(
                'Não foi possível encontrar essa $nomeTipo',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    if (dados!.status == 'Transferida') {
      final alvo = AlvoTransferencia(
          id: widget.tipo == TipoCardapio.mesa ? idMesa : idComanda,
          atendimento: idComandaPedido,
          nome: dados!.nome ?? nomeTipo,
          tipo: widget.tipo == TipoCardapio.mesa ? 'mesa' : 'comanda');
      return Scaffold(
        backgroundColor: VisualAtendimento.superficie(context),
        appBar: AppBar(
            backgroundColor: cs.inversePrimary,
            title: Text('Detalhes da $nomeTipo')),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Icon(Icons.drive_file_move_outline,
              size: 40, color: VisualAtendimento.azul(context)),
          const SizedBox(height: 16),
          const Text('Atendimento transferido',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
              'Os pedidos foram movidos para outro atendimento. Esta origem não recebe novos itens.',
              textAlign: TextAlign.center),
          const SizedBox(height: 20),
          OutlinedButton.icon(
              onPressed: () => abrirHistoricoTransferencias(context, alvo),
              icon: const Icon(Icons.history),
              label: const Text('Histórico de transferências')),
        ]),
      );
    }

    final emFechamento = dados!.status == 'Fechamento';
    final corStatus =
        emFechamento ? _corFechamento : VisualAtendimento.verde(context);
    final labelStatus = emFechamento ? 'Em fechamento' : 'Em andamento';

    return Scaffold(
      backgroundColor: VisualAtendimento.superficie(context),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        title: Text('Detalhes da $nomeTipo',
            style: const TextStyle(fontWeight: FontWeight.w600)),
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
                dataAbertura: dados!.dataAbertura,
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
                            nomeAtendimento: dados!.nome,
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
                            nomeAtendimento: dados!.nome,
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
                onReimprimirPreparo: _reimprimirComprovantePreparo,
                onEditar: () {
                  if (emFechamento) {
                    _avisoFechamento();
                    return;
                  }
                  final idRecurso =
                      widget.tipo == TipoCardapio.mesa ? idMesa : idComanda;
                  if (idRecurso != '0') {
                    Navigator.of(context)
                        .push(MaterialPageRoute(
                      builder: (context) => PaginaComandaDesocupada(
                        id: idRecurso,
                        idComandaPedido: idComandaPedido,
                        nome: dados!.nome!,
                        tipo: widget.tipo,
                      ),
                    ))
                        .then((_) {
                      if (mounted) listarComandasPedidos();
                    });
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
          if (carregando || _reimprimindoPreparo)
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

  String _resolverCliente() =>
      nomeClienteAtendimento(dados!.nomeCliente, dados!.observacaoDoPedido);
}

class _CabecalhoComanda extends StatelessWidget {
  final String nome;
  final String cliente;
  final String statusLabel;
  final Color corStatus;
  final String? numeroPedido;
  final String? dataAbertura;

  const _CabecalhoComanda({
    required this.nome,
    required this.cliente,
    required this.statusLabel,
    required this.corStatus,
    this.numeroPedido,
    this.dataAbertura,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusAtendimento(texto: statusLabel, cor: corStatus),
              if (numeroPedido?.isNotEmpty == true)
                Text('#$numeroPedido',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ]),
        const SizedBox(height: 16),
        Text(nome,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.person_outline_rounded,
              size: 20, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(cliente, style: const TextStyle(fontSize: 15))),
        ]),
        const SizedBox(height: 12),
        Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(Icons.schedule_rounded,
                  size: 18, color: cs.onSurfaceVariant),
              Text('Tempo aberta:',
                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
              TempoAberto(
                  dataAbertura: dataAbertura,
                  textStyle: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
      ]),
    );
  }
}

class _AcoesGrid extends StatelessWidget {
  final TipoCardapio tipo;
  final VoidCallback onAdicionar;
  final VoidCallback onItensRecorrentes;
  final VoidCallback onPedidos;
  final VoidCallback onReimprimirPreparo;
  final VoidCallback onEditar;

  const _AcoesGrid(
      {required this.tipo,
      required this.onAdicionar,
      required this.onItensRecorrentes,
      required this.onPedidos,
      required this.onReimprimirPreparo,
      required this.onEditar});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FilledButton.icon(
        onPressed: onAdicionar,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar produtos'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          textStyle: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      const SizedBox(height: 12),
      for (final acao in [
        (Icons.history_rounded, 'Itens recorrentes', onItensRecorrentes),
        (Icons.receipt_long_outlined, 'Pedidos', onPedidos),
        (
          Icons.print_outlined,
          'Reimprimir comprovante de preparo',
          onReimprimirPreparo
        ),
        (Icons.edit_outlined, 'Editar ${tipo.nome}', onEditar),
      ]) ...[
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          minLeadingWidth: 28,
          leading: Icon(acao.$1, color: cs.primary),
          title: Text(acao.$2,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
          trailing:
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
          onTap: acao.$3,
        ),
        const Divider(height: 1),
      ],
    ]);
  }
}

class _PainelConta extends StatelessWidget {
  final bool emFechamento;
  final String total;
  final VoidCallback onFechar;
  final VoidCallback onAbrir;

  const _PainelConta(
      {required this.emFechamento,
      required this.total,
      required this.onFechar,
      required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Conta',
            style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        const SizedBox(height: 6),
        if (usuarioProvedor
                .usuario?.configuracoes?.habilitarVerValorTotalNoApp ==
            'Sim')
          Text((double.tryParse(total) ?? 0).obterReal(),
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: VisualAtendimento.verde(context)))
        else
          const BadgeValorOculto(compact: false, label: 'Valor total oculto'),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          key: const ValueKey('acao_conta'),
          onPressed: emFechamento ? onAbrir : onFechar,
          icon: Icon(
              emFechamento ? Icons.lock_open_rounded : Icons.print_outlined),
          label: Text(emFechamento ? 'Reabrir' : 'Fechar conta'),
          style: OutlinedButton.styleFrom(
            foregroundColor:
                emFechamento ? VisualAtendimento.verde(context) : cs.primary,
            minimumSize: const Size(0, 52),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ]),
    );
  }
}
