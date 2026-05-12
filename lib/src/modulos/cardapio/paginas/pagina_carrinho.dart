import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_dados_cardapio.dart';
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
import 'package:flutter_modular/flutter_modular.dart';

class PaginaCarrinho extends StatefulWidget {
  const PaginaCarrinho({super.key});

  @override
  State<PaginaCarrinho> createState() => _PaginaCarrinhoState();
}

class _PaginaCarrinhoState extends State<PaginaCarrinho> with TickerProviderStateMixin {
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ServicoCardapio servicoCardapio = Modular.get<ServicoCardapio>();
  final ProvedorComanda provedorComanda = Modular.get<ProvedorComanda>();
  final ProvedorMesas provedorMesas = Modular.get<ProvedorMesas>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorFinalizarPagamento provedorFinalizarPagamento = Modular.get<ProvedorFinalizarPagamento>();
  final Server server = Modular.get<Server>();

  bool isLoading = false;
  Modeloworddadoscardapio? dados;
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    listar();
  }

  void listar() async {
    await carrinhoProvedor.listarComandasPedidos();
    await servicoCardapio.listarPorId(provedorCardapio.id, provedorCardapio.tipo, "Não").then((value) {
      dados = value;
    });
    setState(() => carregando = false);
  }

  void removerTodosItensCarrinho() async {
    await carrinhoProvedor.removerComandasPedidos().then((sucesso) {
      if (mounted) carrinhoProvedor.listarComandasPedidos();
      if (sucesso) return;
      if (mounted) {
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
    });
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
                    child: Icon(Icons.delete_sweep_outlined, color: cs.onErrorContainer, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text('Esvaziar carrinho', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Future<void> _finalizar() async {
    if (isLoading) return;
    setState(() => isLoading = true);

    provedorFinalizarPagamento.idVenda = provedorCardapio.id;
    provedorFinalizarPagamento.valor = carrinhoProvedor.itensCarrinho.precoTotal;

    if (provedorCardapio.tipo == TipoCardapio.balcao) {
      setState(() => isLoading = false);
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: 'PaginaFinalizarAcrescimo'),
          builder: (context) => const PaginaFinalizarAcrescimo(),
        ),
      );
      return;
    }

    if (provedorCardapio.tipo == TipoCardapio.mesa) {
      await servicoCardapio
          .inserirProdutosMesa(
        carrinhoProvedor.itensCarrinho.listaComandosPedidos,
        provedorCardapio.idMesa,
        provedorCardapio.id,
        provedorCardapio.idCliente,
      )
          .then((resposta) {
        var (sucesso, _) = resposta;
        if (sucesso) {
          provedorMesas.listarMesas('');
          server.write(jsonEncode({'tipo': 'Mesa', 'nomeConexao': usuarioProvedor.usuario!.nome}));
          removerTodosItensCarrinho();
          Impressao.comprovanteDePedido(
            tipodeentrega: provedorCardapio.tipodeentrega,
            tipoTela: provedorCardapio.tipo,
            comanda: dados!.nome!,
            numeroPedido: dados!.numeroPedido!,
            nomeCliente: ((dados?.nomeCliente ?? 'Sem Cliente') == 'Sem Cliente' || (dados?.nomeCliente ?? 'Sem Cliente') == '') && (dados?.observacaoDoPedido ?? '').isNotEmpty ? (dados?.observacaoDoPedido ?? '') : (dados?.nomeCliente ?? 'Sem Cliente'),
            nomeEmpresa: dados!.nomeEmpresa!,
            produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
            local: '',
          );
          if (context.mounted) {
            Navigator.popUntil(context, ModalRoute.withName('PaginaMesas'));
          }
          return;
        }
        _erroSnack();
      }).whenComplete(() {
        if (mounted) setState(() => isLoading = false);
      });
      return;
    }

    await servicoCardapio
        .inserirProdutosComanda(
      carrinhoProvedor.itensCarrinho.listaComandosPedidos,
      provedorCardapio.idMesa,
      provedorCardapio.id,
      provedorCardapio.idComanda,
      provedorCardapio.idCliente,
    )
        .then((resposta) {
      var (sucesso, _) = resposta;
      if (sucesso) {
        provedorComanda.listarComandas('');
        server.write(jsonEncode({'tipo': 'Comanda', 'nomeConexao': usuarioProvedor.usuario!.nome}));
        removerTodosItensCarrinho();
        Impressao.comprovanteDePedido(
          tipodeentrega: provedorCardapio.tipodeentrega,
          tipoTela: provedorCardapio.tipo,
          comanda: dados!.nome!,
          numeroPedido: dados!.numeroPedido!,
          nomeCliente: ((dados?.nomeCliente ?? 'Sem Cliente') == 'Sem Cliente' || (dados?.nomeCliente ?? 'Sem Cliente') == '') && (dados?.observacaoDoPedido ?? '').isNotEmpty ? (dados?.observacaoDoPedido ?? '') : (dados?.nomeCliente ?? 'Sem Cliente'),
          nomeEmpresa: dados!.nomeEmpresa!,
          produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
          local: dados?.nomeMesa ?? '',
        );
        if (context.mounted) {
          Navigator.popUntil(context, ModalRoute.withName('PaginaComandas'));
        }
        return;
      }
      _erroSnack();
    }).whenComplete(() {
      if (mounted) setState(() => isLoading = false);
    });
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
    final itens = carrinhoProvedor.itensCarrinho.listaComandosPedidos;

    return AnimatedBuilder(
      animation: carrinhoProvedor,
      builder: (context, _) => Scaffold(
        backgroundColor: cs.surface,
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
                child: Icon(Icons.shopping_cart_outlined, color: cs.onPrimaryContainer, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Carrinho', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.1)),
                  Text(
                    '${itens.length} ${itens.length == 1 ? "item" : "itens"}',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            if (carrinhoProvedor.itensCarrinho.listaComandosPedidos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  tooltip: 'Esvaziar',
                  onPressed: _confirmarLimpar,
                  icon: Icon(Icons.delete_sweep_outlined, color: cs.error),
                ),
              ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
        floatingActionButton: (carregando || itens.isEmpty)
            ? null
            : _BotaoFinalizar(
                isLoading: isLoading,
                total: carrinhoProvedor.itensCarrinho.precoTotal,
                onTap: _finalizar,
              ),
        body: carregando
            ? const Center(child: CircularProgressIndicator())
            : itens.isEmpty
                ? _EstadoVazio(cs: cs)
                : ListView.builder(
                    itemCount: itens.length,
                    padding: const EdgeInsets.fromLTRB(10, 12, 10, 130),
                    itemBuilder: (context, index) {
                      final item = itens[index];
                      return CardCarrinho(
                        item: item,
                        idComanda: provedorCardapio.idComanda,
                        idMesa: provedorCardapio.idMesa,
                        index: index,
                        value: carrinhoProvedor.itensCarrinho,
                        setarQuantidade: (increase) {
                          setState(() {
                            item.quantidade = item.quantidade! + (increase ? 1 : -1);
                          });
                          double precoTotal = 0;
                          for (final e in carrinhoProvedor.itensCarrinho.listaComandosPedidos) {
                            precoTotal += double.parse(e.valorVenda) * e.quantidade!;
                          }
                          setState(() => carrinhoProvedor.itensCarrinho.precoTotal = precoTotal);
                        },
                      );
                    },
                  ),
      ),
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
            child: Icon(Icons.shopping_cart_outlined, size: 48, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          Text(
            'Seu carrinho está vazio',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: cs.onSurface),
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

class _BotaoFinalizar extends StatelessWidget {
  final bool isLoading;
  final double total;
  final VoidCallback onTap;

  const _BotaoFinalizar({
    required this.isLoading,
    required this.total,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        width: width - 28,
        height: 56,
        child: FilledButton(
          onPressed: isLoading ? null : onTap,
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 18),
            elevation: 3,
          ),
          child: isLoading
              ? SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: cs.onPrimary),
                )
              : Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 22, color: cs.onPrimary),
                    const SizedBox(width: 10),
                    const Text('Finalizar', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: cs.onPrimary.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        total.obterReal(),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
