import 'dart:convert';
import 'dart:developer' as developer;
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:app/src/essencial/api/conexao.dart';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';

import 'package:app/src/essencial/utils/finalizacao_com_preparo.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/modelos/contexto_carrinho.dart';
import 'package:app/src/modulos/cardapio/modelos/itens_comanda_modelo.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/widgets/card_carrinho.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_finalizar_acrescimo.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:app/src/essencial/widgets/visual_atendimento.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinho extends StatefulWidget {
  final ContextoCarrinho? contextoVoz;
  final String? assinaturaVoz, servidorVoz, usuarioVoz;
  final bool retornarParaFinalizacao;
  const PaginaCarrinho(
      {super.key,
      this.contextoVoz,
      this.assinaturaVoz,
      this.servidorVoz,
      this.usuarioVoz,
      this.retornarParaFinalizacao = false});

  @override
  State<PaginaCarrinho> createState() => _PaginaCarrinhoState();
}

class _PaginaCarrinhoState extends State<PaginaCarrinho>
    with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorFinalizarPagamento provedorFinalizarPagamento =
      Modular.get<ProvedorFinalizarPagamento>();
  final Server server = Modular.get<Server>();
  late final ContextoCarrinho? _contextoCarrinho;
  late final TipoCardapio _tipo;
  late final String _tipoDeEntrega;

  String get _idMesa =>
      dados?.idMesa ??
      (_tipo == TipoCardapio.mesa ? _contextoCarrinho?.idRecurso : null) ??
      '0';
  String get _idComanda =>
      dados?.idComanda ??
      (_tipo == TipoCardapio.comanda ? _contextoCarrinho?.idRecurso : null) ??
      '0';

  bool isLoading = false;
  final _finalizacao = FinalizacaoComPreparo();
  ItensModeloComandao? _resumoDelivery;
  double? _saldoDelivery;
  Modeloworddadoscardapio? dados;
  bool carregando = true;
  bool _tentouEnvioVoz = false;

  @override
  void initState() {
    super.initState();
    _contextoCarrinho = carrinhoProvedor.contexto;
    _tipo = _contextoCarrinho == null
        ? provedorCardapio.tipo
        : TipoCardapio.values.byName(_contextoCarrinho!.tipo);
    _tipoDeEntrega = provedorCardapio.tipodeentrega;
    listar();
  }

  Future<void> listar() async {
    final contextoCarrinho = _contextoCarrinho;
    try {
      dados = null;
      if (contextoCarrinho == null || !contextoCarrinho.valido) {
        throw StateError('Carrinho sem atendimento.');
      }
      await carrinhoProvedor.listarComandasPedidos();
      final resposta = await servicoCardapio.listarPorId(
          contextoCarrinho.idAtendimento, _tipo, "Não");
      if (_tipo == TipoCardapio.comanda || _tipo == TipoCardapio.mesa) {
        final recurso = _tipo == TipoCardapio.comanda
            ? resposta.idComanda
            : resposta.idMesa;
        if (resposta.id != contextoCarrinho.idAtendimento ||
            (contextoCarrinho.idRecurso.isNotEmpty &&
                recurso != contextoCarrinho.idRecurso)) {
          throw StateError(
              'Os dados nao pertencem ao atendimento do carrinho.');
        }
      }
      if (mounted) dados = resposta;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Não foi possível consultar o atendimento.'),
          action: SnackBarAction(
              label: 'Tentar novamente',
              onPressed: () {
                setState(() => carregando = true);
                listar();
              }),
        ));
      }
    } finally {
      if (mounted) setState(() => carregando = false);
    }
    if (mounted &&
        dados != null &&
        widget.contextoVoz != null &&
        !_tentouEnvioVoz) {
      _tentouEnvioVoz = true;
      await WidgetsBinding.instance.endOfFrame;
      if (mounted &&
          ModalRoute.of(context)?.isCurrent == true &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        await _finalizar(voz: true);
      }
    }
  }

  Future<void> removerTodosItensCarrinho() async {
    final sucesso = await carrinhoProvedor.removerComandasPedidos(
        contexto: _contextoCarrinho);

    if (!sucesso) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ocorreu um erro'),
            showCloseIcon: true,
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
      return;
    }

    await carrinhoProvedor.listarComandasPedidos();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _confirmarLimpar() async {
    final cs = Theme.of(context).colorScheme;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
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
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_sweep_outlined,
                        color: cs.onErrorContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Esvaziar carrinho',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Deseja realmente excluir todos os produtos do carrinho?',
                style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
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
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(ctx, true),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Excluir'),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
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
      ),
    );
    if (ok == true) removerTodosItensCarrinho();
  }

  Future<void> _finalizar({bool voz = false}) async {
    if (isLoading ||
        carregando ||
        _contextoCarrinho == null ||
        carrinhoProvedor.contexto?.chave != _contextoCarrinho?.chave ||
        dados == null ||
        (carrinhoProvedor.itensCarrinho.listaComandosPedidos.isEmpty &&
            !_finalizacao.pedidoRegistrado)) {
      return;
    }
    provedorFinalizarPagamento.idVenda = _contextoCarrinho!.idAtendimento;
    provedorFinalizarPagamento.valor =
        carrinhoProvedor.itensCarrinho.precoTotal;
    if (_tipo == TipoCardapio.balcao) {
      Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'PaginaFinalizarAcrescimo'),
            builder: (_) => const PaginaFinalizarAcrescimo(),
          ));
      return;
    }
    if (_tipo == TipoCardapio.delivery) {
      await _finalizarDelivery();
      return;
    }
    setState(() => isLoading = true);
    final tipo = _tipo;
    final contextoCarrinho = _contextoCarrinho!;
    final dadosPedido = dados!;
    final idMesa = _idMesa;
    final idComanda = _idComanda;
    final idCliente = dadosPedido.idCliente ?? '0';
    try {
      final itens =
          await carrinhoProvedor.obterItensParaFinalizar(contextoCarrinho);
      if (voz &&
          (!identical(widget.contextoVoz, contextoCarrinho) ||
              widget.usuarioVoz != usuarioProvedor.usuario?.id ||
              widget.servidorVoz != (await Apis().getConexao()).servidor ||
              itens.length != 1 ||
              jsonEncode(itens.map((i) => i.toMap()).toList()) !=
                  widget.assinaturaVoz ||
              Sincronizador.instancia == null)) {
        throw StateError(
            'O pedido mudou depois da gravação. Confira o carrinho antes de finalizar.');
      }
      if (itens.isEmpty && !_finalizacao.pedidoRegistrado) {
        throw StateError('O carrinho nao tem produtos pendentes.');
      }
      final sucesso = await _finalizacao.executar(
        registrarPedidoDuravel: Sincronizador.instancia == null
            ? null
            : (mensagens) => Sincronizador.instancia!.guardarPedido(
                contexto: contextoCarrinho,
                itens: itens,
                idMesa: idMesa,
                idComanda: idComanda,
                idCliente: idCliente,
                impressoes: mensagens),
        prepararImpressao: () => Impressao.prepararComprovanteDePedido(
          produtos: itens,
          tipoTela: tipo,
          tipodeentrega: _tipoDeEntrega,
          comanda: dadosPedido.nome ?? '',
          numeroPedido: dadosPedido.numeroPedido ?? '',
          nomeCliente: nomeClienteAtendimento(
              dadosPedido.nomeCliente, dadosPedido.observacaoDoPedido,
              vazio: ''),
          nomeEmpresa: dadosPedido.nomeEmpresa ?? '',
          local: tipo == TipoCardapio.mesa ? '' : dadosPedido.nomeMesa ?? '',
        ),
        registrarPedido: () async {
          final resposta = tipo == TipoCardapio.mesa
              ? await servicoCardapio.inserirProdutosMesa(
                  itens, idMesa, contextoCarrinho.idAtendimento, idCliente)
              : await servicoCardapio.inserirProdutosComanda(itens, idMesa,
                  contextoCarrinho.idAtendimento, idComanda, idCliente);
          return resposta.$1;
        },
        enviarImpressao: server.enviarImpressoes,
        aoFalharImpressao: server.avisarFalhaImpressao,
        salvarImpressaoAntesDoPedido: server.prepararImpressoes,
        cancelarImpressaoPreparada: server.filaImpressao.cancelarPreparacao,
        limparCarrinho: () async {
          if (!await carrinhoProvedor.removerComandasPedidos(
              contexto: contextoCarrinho)) {
            throw StateError('Nao foi possivel limpar o carrinho finalizado.');
          }
          await carrinhoProvedor.listarComandasPedidos();
        },
      );
      if (!sucesso) {
        throw StateError('Pedido nao registrado.');
      }
      FeedbackUsuario.pedidoFinalizado();
      server.write(jsonEncode({
        'tipo': tipo.nome,
        'nomeConexao': usuarioProvedor.usuario?.nome ?? ''
      }));
      if (tipo == TipoCardapio.mesa) {
        provedorMesas.listarMesas('');
      } else {
        provedorComanda.listarComandas('');
      }
      if (mounted) {
        setState(() => isLoading = false);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        if (widget.retornarParaFinalizacao) {
          Navigator.popUntil(
            context,
            (route) =>
                route.settings.name == 'PaginaFinalizarContaAtendimento' ||
                route.isFirst,
          );
        } else {
          Navigator.popUntil(
              context,
              ModalRoute.withName(tipo == TipoCardapio.mesa
                  ? 'PaginaMesas'
                  : 'PaginaComandas'));
        }
      }
    } catch (erro) {
      if (mounted) {
        setState(() => isLoading = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(_finalizacao.pedidoRegistrado
                ? 'Pedido ja registrado'
                : 'Nao foi possivel finalizar'),
            content: Text(_finalizacao.pedidoRegistrado
                ? 'A finalizacao ficou pendente. Confira com a cozinha. Toque em Finalizar novamente para concluir a impressao e limpar o carrinho, sem lancar os produtos outra vez.'
                : erro is StateError
                    ? erro.message.toString()
                    : 'Confira a conexao e consulte os itens do pedido antes de tentar novamente.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Entendi'))
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _finalizarDelivery() async {
    setState(() => isLoading = true);
    try {
      final contexto = _contextoCarrinho!;
      final itens = await carrinhoProvedor.obterItensParaFinalizar(contexto);
      final servicoDelivery = Modular.get<ServicoDelivery>();
      if (!_finalizacao.pedidoRegistrado) {
        _resumoDelivery = carrinhoProvedor.itensCarrinho;
      }
      final sucesso = await _finalizacao.executar(
        prepararImpressao: () => [],
        registrarPedido: () async {
          await servicoDelivery.inserirProdutos(contexto.idAtendimento, itens);
          return true;
        },
        enviarImpressao: (_) async {},
        limparCarrinho: () async {
          // Os itens enviados deixam o rascunho persistido. O resumo permanece
          // visivel se a consulta do pagamento falhar, sem permitir reenvio.
          if (!await carrinhoProvedor.removerComandasPedidos(
              contexto: contexto)) {
            throw StateError(
                'Pedido salvo. Não foi possível limpar o carrinho.');
          }
        },
      );
      if (!sucesso) {
        throw StateError('Não foi possível salvar o pedido.');
      }
      if (!mounted) return;
      final pedido = await servicoDelivery.pedido(contexto.idAtendimento);
      if (!mounted) return;
      _saldoDelivery = pedido.restante;
      provedorFinalizarPagamento.idVenda = contexto.idAtendimento;
      provedorFinalizarPagamento.valor = _saldoDelivery!;
      setState(() => isLoading = false);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      Navigator.push(
          context,
          MaterialPageRoute(
            settings: const RouteSettings(name: 'PaginaFinalizarAcrescimo'),
            builder: (_) => const PaginaFinalizarAcrescimo(),
          ));
    } catch (e, stack) {
      developer.log('Falha ao abrir pagamento do Delivery',
          name: 'PaginaCarrinho', error: e, stackTrace: stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_finalizacao.pedidoRegistrado
                ? 'Pedido salvo. Não foi possível abrir o pagamento. Toque em Finalizar para tentar novamente, sem reenviar os itens.'
                : e is StateError
                    ? e.message.toString()
                    : 'Não foi possível confirmar o pedido. Confira o Delivery antes de tentar novamente.')));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _erroSnack() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ocorreu um erro'),
        showCloseIcon: true,
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: carrinhoProvedor,
      builder: (context, _) {
        final resumo =
            _tipo == TipoCardapio.delivery && _finalizacao.pedidoRegistrado
                ? _resumoDelivery ?? carrinhoProvedor.itensCarrinho
                : carrinhoProvedor.itensCarrinho;
        final itens = resumo.listaComandosPedidos;
        return PopScope(
          canPop: !isLoading &&
              (!_finalizacao.pedidoRegistrado || _finalizacao.concluido),
          onPopInvokedWithResult: (saiu, _) {
            if (!saiu && !isLoading) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Conclua a finalizacao pendente antes de sair do carrinho.'),
              ));
            }
          },
          child: Scaffold(
            extendBody: true,
            backgroundColor: VisualAtendimento.fundo(context),
            appBar: AppBar(
              backgroundColor: cs.inversePrimary,
              elevation: 0,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shopping_cart_outlined,
                        color: cs.onPrimaryContainer, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Carrinho',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0)),
                      Text(
                        '${itens.length} ${itens.length == 1 ? "item" : "itens"}',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: cs.onSurfaceVariant),
                      ),
                    ],
                  )),
                ],
              ),
              actions: [
                if (carrinhoProvedor
                    .itensCarrinho.listaComandosPedidos.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: IconButton(
                      tooltip: 'Esvaziar',
                      onPressed: isLoading || _finalizacao.pedidoRegistrado
                          ? null
                          : _confirmarLimpar,
                      icon: Icon(Icons.delete_sweep_outlined, color: cs.error),
                    ),
                  ),
              ],
            ),
            bottomNavigationBar: (carregando ||
                    (itens.isEmpty && !_finalizacao.pedidoRegistrado))
                ? null
                : SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                      child: BotaoAcaoPedido(
                        carregando: isLoading,
                        rotulo: 'Finalizar',
                        iconeRotulo: Icons.check_circle_outline_rounded,
                        total: (_tipo == TipoCardapio.delivery
                                ? _saldoDelivery ?? resumo.precoTotal
                                : carrinhoProvedor.itensCarrinho.precoTotal)
                            .obterReal(),
                        onPressed: _finalizar,
                      ),
                    )),
            body: IgnorePointer(
              ignoring: isLoading || _finalizacao.pedidoRegistrado,
              child: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : itens.isEmpty
                      ? _EstadoVazio(cs: cs)
                      : ListView.builder(
                          itemCount: itens.length + 1,
                          padding: EdgeInsets.fromLTRB(
                            14,
                            16,
                            14,
                            MediaQuery.paddingOf(context).bottom +
                                MediaQuery.textScalerOf(context).scale(96),
                          ),
                          itemBuilder: (context, posicao) {
                            if (posicao == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        dados?.nome?.trim().isNotEmpty == true
                                            ? dados!.nome!
                                            : _tipo.nome,
                                        key: const ValueKey('destino_carrinho'),
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w700)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'Novos itens - ${itens.where((item) => item.conferidoNoCarrinho).length}/${itens.length} conferidos',
                                        style: TextStyle(
                                            color: cs.onSurfaceVariant,
                                            fontSize: 13)),
                                  ],
                                ),
                              );
                            }
                            final index = posicao - 1;
                            final item = itens[index];
                            return CardCarrinho(
                              item: item,
                              idComanda: _idComanda,
                              idMesa: _idMesa,
                              index: index,
                              value: resumo,
                              aoExcluirItem: () => setState(() {}),
                              setarQuantidade: (increase) async {
                                final quantidadeAnterior = item.quantidade ?? 1;
                                final novaQuantidade =
                                    quantidadeAnterior + (increase ? 1 : -1);
                                if (novaQuantidade < 1) return false;

                                item.quantidade = novaQuantidade;
                                if (mounted) setState(() {});

                                final sucesso =
                                    await carrinhoProvedor.editar(item, index);
                                if (!sucesso) {
                                  item.quantidade = quantidadeAnterior;
                                  if (mounted) setState(() {});
                                  _erroSnack();
                                }
                                return sucesso;
                              },
                            );
                          },
                        ),
            ),
          ),
        );
      },
    );
  }
}

class _EstadoVazio extends StatelessWidget {
  final ColorScheme cs;
  const _EstadoVazio({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.shopping_cart_outlined,
                size: 48, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'Seu carrinho está vazio',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Adicione itens pelo cardápio',
            style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
