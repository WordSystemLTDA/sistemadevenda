import 'dart:convert';
import 'package:app/src/essencial/sincronizacao/sincronizador.dart';

import 'package:app/src/essencial/utils/finalizacao_com_preparo.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/produto/paginas/widgets/botao_acao_pedido.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/servicos/servico_cardapio.dart';
import 'package:app/src/modulos/comandas/paginas/pagina_comandas.dart';
import 'package:app/src/modulos/comandas/provedores/provedor_comandas.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/itens_recorrentes/paginas/widgets/card_carrinho_itens_recorrentes.dart';
import 'package:app/src/modulos/itens_recorrentes/provedores/provedor_itens_recorrentes.dart';
import 'package:app/src/modulos/mesas/paginas/pagina_mesas.dart';
import 'package:app/src/modulos/mesas/provedores/provedor_mesas.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:app/src/essencial/utils/nome_cliente_atendimento.dart';
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinhoItensRecorrentes extends StatefulWidget {
  final String idComanda;
  final String idComandaPedido;
  final String idMesa;
  final String idCliente;
  final TipoCardapio tipo;

  const PaginaCarrinhoItensRecorrentes({
    super.key,
    required this.idComanda,
    required this.idComandaPedido,
    required this.idMesa,
    required this.idCliente,
    required this.tipo,
  });

  @override
  State<PaginaCarrinhoItensRecorrentes> createState() =>
      _PaginaCarrinhoItensRecorrentesState();
}

class _PaginaCarrinhoItensRecorrentesState
    extends State<PaginaCarrinhoItensRecorrentes>
    with TickerProviderStateMixin {
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorFinalizarPagamento provedorFinalizarPagamento =
      Modular.get<ProvedorFinalizarPagamento>();
  final ProvedorItensRecorrentes provedorItensRecorrentes =
      Modular.get<ProvedorItensRecorrentes>();
  final Server server = Modular.get<Server>();

  bool isLoading = false;
  final _finalizacao = FinalizacaoComPreparo();
  Modeloworddadoscardapio? dados;
  bool carregando = true;

  TipoCardapio get _tipo => widget.tipo;

  @override
  void initState() {
    super.initState();
    listar();
  }

  Future<void> listar() async {
    try {
      dados = null;
      await provedorItensRecorrentes
          .listarComandasPedidos(widget.idComandaPedido);
      final resposta = await servicoCardapio.listarPorId(
          widget.idComandaPedido, _tipo, "Não");
      if (resposta.id != widget.idComandaPedido ||
          (_tipo == TipoCardapio.comanda
              ? resposta.idComanda != widget.idComanda
              : resposta.idMesa != widget.idMesa)) {
        throw StateError('Os dados nao pertencem ao atendimento do carrinho.');
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
  }

  Future<void> removerTodosItensCarrinho() async {
    // aqui
    await provedorItensRecorrentes
        .removerComandasPedidos(widget.idComandaPedido);
    // List<String> listaIdItemComanda = [];
    // for (int index = 0; index < carrinhoProvedor.itensCarrinho.listaComandosPedidos.length; index++) {
    //   listaIdItemComanda.add(carrinhoProvedor.itensCarrinho.listaComandosPedidos[index].id);
    // }

    // await carrinhoProvedor.removerComandasPedidos().then((sucesso) {
    //   if (mounted) {
    //     carrinhoProvedor.listarComandasPedidos();
    //   }

    //   if (sucesso) return;

    //   if (mounted) {
    //     ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //       content: Text('Ocorreu um erro'),
    //       showCloseIcon: true,
    //     ));
    //   }
    // });
  }

  void _voltarParaTelaOrigem({required bool mesa}) {
    final navigator = Navigator.of(context);
    final nomeRota = mesa ? 'PaginaMesas' : 'PaginaComandas';
    var encontrouRota = false;

    navigator.popUntil((route) {
      if (route.settings.name == nomeRota) {
        encontrouRota = true;
        return true;
      }
      return route.isFirst;
    });

    if (encontrouRota) return;

    navigator.push(MaterialPageRoute(
      settings: RouteSettings(name: nomeRota),
      builder: (context) => mesa ? const PaginaMesas() : const PaginaComandas(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: provedorItensRecorrentes,
      builder: (context, _) {
        final temItens = provedorItensRecorrentes.itensCarrinho.isNotEmpty;
        final quantidadeItens = provedorItensRecorrentes.itensCarrinho
            .fold<int>(
                0, (acc, item) => acc + ((item.quantidade ?? 0).toInt()));
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
            backgroundColor:
                isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
            appBar: AppBar(
              backgroundColor: cs.inversePrimary,
              elevation: 0,
              centerTitle: false,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.shopping_cart_rounded,
                        size: 18, color: cs.onPrimaryContainer),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Carrinho',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (temItens) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${provedorItensRecorrentes.itensCarrinho.length}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                if (temItens)
                  IconButton(
                    tooltip: 'Esvaziar carrinho',
                    onPressed: isLoading || _finalizacao.pedidoRegistrado
                        ? null
                        : () => _confirmarExcluirTodos(context),
                    icon: Icon(Icons.delete_sweep_rounded,
                        color: Colors.red.shade400),
                  ),
              ],
            ),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButtonAnimator:
                FloatingActionButtonAnimator.noAnimation,
            floatingActionButton:
                (carregando || (!temItens && !_finalizacao.pedidoRegistrado))
                    ? null
                    : _buildBotaoFinalizar(context, quantidadeItens),
            body: IgnorePointer(
              ignoring: isLoading || _finalizacao.pedidoRegistrado,
              child: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : !temItens
                      ? _buildCarrinhoVazio(context)
                      : Column(
                          children: [
                            _buildResumoTopo(context, quantidadeItens),
                            Expanded(
                              child: ListView.builder(
                                itemCount: provedorItensRecorrentes
                                    .itensCarrinho.length,
                                padding: const EdgeInsets.only(
                                    bottom: 150, left: 12, right: 12, top: 4),
                                itemBuilder: (context, index) {
                                  final item = provedorItensRecorrentes
                                      .itensCarrinho[index];

                                  return CardCarrinhoItensRecorrentes(
                                    item: item,
                                    idComanda: widget.idComanda,
                                    idComandaPedido: widget.idComandaPedido,
                                    idMesa: widget.idMesa,
                                    index: index,
                                    value: null,
                                    setarQuantidade: (increase) async {
                                      if (increase) {
                                        await provedorItensRecorrentes
                                            .setarItemCarrinho(
                                                widget.idComandaPedido,
                                                index,
                                                (item.quantidade ?? 1) + 1);
                                        if (context.mounted) {
                                          provedorItensRecorrentes
                                              .listarComandasPedidos(
                                                  widget.idComandaPedido);
                                        }
                                      } else {
                                        await provedorItensRecorrentes
                                            .setarItemCarrinho(
                                                widget.idComandaPedido,
                                                index,
                                                (item.quantidade ?? 1) - 1);
                                        if (context.mounted) {
                                          provedorItensRecorrentes
                                              .listarComandasPedidos(
                                                  widget.idComandaPedido);
                                        }
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmarExcluirTodos(BuildContext context) async {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    await showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        color: Colors.red.shade400, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Esvaziar carrinho?',
                      style:
                          TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Todos os itens adicionados serão removidos. Essa ação não pode ser desfeita.',
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: cs.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await removerTodosItensCarrinho();
                      if (dialogContext.mounted) {
                        provedorItensRecorrentes
                            .listarComandasPedidos(widget.idComandaPedido);
                        Navigator.of(dialogContext).pop();
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Excluir tudo'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade400,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResumoTopo(BuildContext context, int quantidadeItens) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : cs.outline.withValues(alpha: 0.12),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: cs.primaryContainer.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.shopping_bag_outlined,
                  color: cs.onPrimaryContainer, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${provedorItensRecorrentes.itensCarrinho.length} ${provedorItensRecorrentes.itensCarrinho.length == 1 ? "item" : "itens"} · qtd $quantidadeItens',
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    'Revise antes de finalizar',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: cs.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'TOTAL',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: cs.onSurface.withValues(alpha: 0.55),
                  ),
                ),
                Text(
                  provedorItensRecorrentes.precoTotal.obterReal(),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCarrinhoVazio(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.remove_shopping_cart_outlined,
              size: 48,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Carrinho vazio',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Adicione itens recorrentes para continuar',
            style: TextStyle(
              fontSize: 13,
              color: cs.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 22),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('Voltar'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotaoFinalizar(BuildContext context, int quantidadeItens) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: BotaoAcaoPedido(
        rotulo: 'Finalizar',
        total: provedorItensRecorrentes.precoTotal.obterReal(),
        quantidade: quantidadeItens,
        carregando: isLoading,
        onPressed: _aoFinalizar,
      ),
    );
  }

  Future<void> _aoFinalizar() async {
    if (isLoading ||
        carregando ||
        provedorItensRecorrentes.contexto?.idAtendimento !=
            widget.idComandaPedido ||
        dados == null ||
        (provedorItensRecorrentes.itensCarrinho.isEmpty &&
            !_finalizacao.pedidoRegistrado)) {
      return;
    }
    setState(() => isLoading = true);
    final tipo = _tipo;
    final dadosPedido = dados!;
    try {
      final itens = await provedorItensRecorrentes
          .obterItensParaFinalizar(widget.idComandaPedido);
      if (itens.isEmpty && !_finalizacao.pedidoRegistrado) {
        throw StateError('O carrinho nao tem produtos pendentes.');
      }
      final sucesso = await _finalizacao.executar(
        registrarPedidoDuravel: Sincronizador.instancia == null
            ? null
            : (mensagens) => Sincronizador.instancia!.guardarPedido(
                contexto: provedorItensRecorrentes.contexto!,
                itens: itens,
                idMesa: widget.idMesa,
                idComanda: widget.idComanda,
                idCliente: dadosPedido.idCliente ?? '0',
                impressoes: mensagens,
                recorrentes: true),
        prepararImpressao: () => Impressao.prepararComprovanteDePedido(
          produtos: itens,
          tipoTela: tipo,
          tipodeentrega: '',
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
              ? await servicoCardapio.inserirProdutosMesa(itens, widget.idMesa,
                  widget.idComandaPedido, dadosPedido.idCliente ?? '0')
              : await servicoCardapio.inserirProdutosComanda(
                  itens,
                  widget.idMesa,
                  widget.idComandaPedido,
                  widget.idComanda,
                  dadosPedido.idCliente ?? '0');
          return resposta.$1;
        },
        enviarImpressao: server.enviarImpressoes,
        salvarImpressaoAntesDoPedido: server.prepararImpressoes,
        cancelarImpressaoPreparada: server.filaImpressao.cancelarPreparacao,
        limparCarrinho: () async {
          if (!await provedorItensRecorrentes
              .removerComandasPedidos(widget.idComandaPedido)) {
            throw StateError('Nao foi possivel limpar o carrinho finalizado.');
          }
          await provedorItensRecorrentes
              .listarComandasPedidos(widget.idComandaPedido);
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
        _voltarParaTelaOrigem(mesa: tipo == TipoCardapio.mesa);
      }
    } catch (erro) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(_finalizacao.pedidoRegistrado
                ? 'Finalizacao pendente. Toque em Finalizar novamente para concluir sem lancar os produtos outra vez.'
                : erro is StateError
                    ? erro.message.toString()
                    : 'Nao foi possivel finalizar. Confira a conexao e tente novamente.'),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Tentar',
              onPressed: _aoFinalizar,
            ),
          ));
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
}
