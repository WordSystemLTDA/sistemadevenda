// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:async';
import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
import 'package:app/src/essencial/servicos/servico_config_bigchef.dart';
import 'package:app/src/essencial/utils/feedback_usuario.dart';
import 'package:app/src/essencial/utils/impressao.dart';
import 'package:app/src/modulos/balcao/provedores/provedor_balcao.dart';
import 'package:app/src/modulos/balcao/servicos/servico_balcao.dart';
import 'package:app/src/modulos/cardapio/modelos/modelo_nome_lancamento.dart';
import 'package:app/src/modulos/cardapio/paginas/pagina_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_cardapio.dart';
import 'package:app/src/modulos/cardapio/provedores/provedor_carrinho.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/banco_pix_modelo.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/pagina_parcelamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/provedores/provedor_finalizar_pagamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:app/src/modulos/delivery/servicos/servico_delivery.dart';
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';
import 'package:app/src/modulos/recorrentes/modelos/modelo_recorrente.dart';
import 'package:app/src/modulos/recorrentes/servicos/servicos_recorrentes.dart';
import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';

class PaginaFinalizarFormaPagamento extends StatefulWidget {
  final double totalReceber;
  final double desconto;
  final String acrescimo;
  final String descontoPercentual;
  final String totalPedido;
  final String pagamentoselecionado;
  final PagamentoRecorrente? recorrencia;

  const PaginaFinalizarFormaPagamento({
    super.key,
    required this.totalReceber,
    required this.desconto,
    required this.acrescimo,
    required this.descontoPercentual,
    required this.totalPedido,
    required this.pagamentoselecionado,
    this.recorrencia,
  });

  @override
  State<PaginaFinalizarFormaPagamento> createState() =>
      _PaginaFinalizarFormaPagamentoState();
}

class _PaginaFinalizarFormaPagamentoState
    extends State<PaginaFinalizarFormaPagamento> {
  final ProvedorFinalizarPagamento provedor =
      Modular.get<ProvedorFinalizarPagamento>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorBalcao provedorBalcao = Modular.get<ProvedorBalcao>();
  final Server server = Modular.get<Server>();

  final ValueNotifier<List<BancoPixModelo>> listaBancoPix = ValueNotifier([]);
  final ValueNotifier<bool> finalizando = ValueNotifier(false);
  final List<TextEditingController> listaBancosControllers = [];

  final _dinheiroController = TextEditingController();
  final _chavePagamento = ServicosRecorrentes.novaChave();

  String dataOriginal = DateFormat('yyyy-MM-dd')
      .format(DateTime.now().add(const Duration(days: 30)));

  double _totalRegistrado = 0;
  double _desconto = 0;
  bool _carregando = true;
  bool trocoEmCredito = false;
  FocusNode? focusNode;

  @override
  void initState() {
    super.initState();
    focusNode = FocusNode();
    focusNode!.requestFocus();

    _totalRegistrado = widget.totalReceber;
    _dinheiroController.text = widget.totalReceber.toStringAsFixed(2);
    _dinheiroController.selection = TextSelection(
        baseOffset: 0, extentOffset: _dinheiroController.text.length);
    listarBancoPix();
  }

  void listarBancoPix() async {
    setState(() => _carregando = true);
    final res =
        await context.read<ServicoFinalizarPagamento>().listarBancoPix();
    if (!mounted) return;

    res
        .map((_) => listaBancosControllers.add(TextEditingController()))
        .toList();
    listaBancoPix.value = res;
    if (mounted) return setState(() => _carregando = false);
  }

  void calcular() {
    final double dinheiro = _dinheiroController.text.isEmpty
        ? 0
        : double.parse(_dinheiroController.text);
    // final double promissoria = _promissoriaController.text.isEmpty ? 0 : double.parse(_promissoriaController.text);
    // final double cartaoDebito = _cartaoDebitoController.text.isEmpty ? 0 : double.parse(_cartaoDebitoController.text);
    // final double cartaoCredito = _cartaoCreditoController.text.isEmpty ? 0 : double.parse(_cartaoCreditoController.text);

    // double totalRegistrado = dinheiro + promissoria + cartaoDebito + cartaoCredito;
    double totalRegistrado = dinheiro;

    listaBancosControllers.map((e) {
      final double banco = e.text.isEmpty ? 0 : double.parse(e.text);

      totalRegistrado += banco;
    }).toList();

    setState(() {
      _desconto = (widget.totalReceber - totalRegistrado) * -1;
      _totalRegistrado = totalRegistrado;
    });
  }

  void _notificarDeliveryFinalizadoEmSegundoPlano(
      ServicoDelivery servico, String id) {
    unawaited(() async {
      try {
        servico.notificarPedidoAtualizado(await servico.pedido(id));
      } catch (_) {}
    }());
  }

  Future<void> _finalizarDelivery() async {
    final servico = Modular.get<ServicoDelivery>();
    final valorRecebido = double.tryParse(_dinheiroController.text) ?? 0;
    final desconto = widget.desconto > 0 ? widget.desconto : 0.0;
    final acrescimo = widget.desconto < 0
        ? widget.desconto.abs()
        : (double.tryParse(widget.acrescimo) ?? 0);
    final pedido = await servico.pedido(provedor.idVenda);

    await servico.pagar(
      pedido,
      int.parse(widget.pagamentoselecionado),
      valorRecebido,
      valorOriginal: widget.totalReceber,
      valorAPagar: widget.totalReceber,
      desconto: desconto,
      acrescimo: acrescimo,
      chavePagamento: _chavePagamento,
      dataLancamento: widget.recorrencia?.vencimento == null
          ? null
          : DateFormat('yyyy-MM-dd').format(widget.recorrencia!.vencimento!),
      parcelasLista: widget.recorrencia?.mensal == true &&
              widget.recorrencia?.vencimento != null
          ? [
              ParcelasModelo(
                  parcela: '1',
                  valor: valorRecebido.toStringAsFixed(2),
                  vencimento: DateFormat('yyyy-MM-dd')
                      .format(widget.recorrencia!.vencimento!))
            ]
          : const [],
    );

    final pagamentoIntegral = valorRecebido + 0.009 >= widget.totalReceber;
    final atualizado =
        pagamentoIntegral ? pedido : await servico.pedido(provedor.idVenda);
    final quitado = pagamentoIntegral || atualizado.restante <= 0.009;
    if (quitado) {
      await servico.concluir(atualizado);
      _notificarDeliveryFinalizadoEmSegundoPlano(servico, provedor.idVenda);
      provedorBalcao.observacaoDoPedido = '';
      await carrinhoProvedor.removerComandasPedidos();
      FeedbackUsuario.pedidoFinalizado();
      if (!mounted) return;
      Navigator.popUntil(
          context,
          (rota) =>
              ['PaginaDelivery', 'PaginaRecorrentes']
                  .contains(rota.settings.name) ||
              rota.isFirst);
      return;
    }

    provedor.valor = atualizado.restante > 0
        ? atualizado.restante
        : widget.totalReceber - valorRecebido;
    if (!mounted) return;
    Navigator.popUntil(
        context, ModalRoute.withName('PaginaFinalizarAcrescimo'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: cs.inversePrimary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.point_of_sale_outlined,
                  size: 18, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 10),
            const Text('Método de Pagamento',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      // resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButton: ValueListenableBuilder(
          valueListenable: finalizando,
          builder: (context, finalizandoValue, _) {
            final habilitado = _dinheiroController.text.isNotEmpty;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Container(
                width: double.infinity,
                height: 58,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: habilitado
                        ? [cs.primary, cs.primary.withValues(alpha: 0.85)]
                        : [Colors.grey.shade400, Colors.grey.shade500],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: habilitado
                      ? [
                          BoxShadow(
                            color: cs.primary.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      if (widget.pagamentoselecionado == '2' &&
                          widget.recorrencia?.mensal != true) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PaginaParcelamento(
                              idVenda: provedor.idVenda,
                              valor:
                                  double.tryParse(_dinheiroController.text) ??
                                      0,
                              valorFalta: (_desconto * -1).toStringAsFixed(2),
                              valorTroco: _desconto.abs().toStringAsFixed(2),
                              // dinheiro: _dinheiroController.text,
                              // promissoria: _promissoriaController.text,
                              // cartaoDebito: _cartaoDebitoController.text,
                              // cartaoCredito: _cartaoCreditoController.text,
                              acrescimo: widget.acrescimo,
                              desconto: widget.desconto.toStringAsFixed(2),
                              descontoPercentual: widget.descontoPercentual,
                              totalPedido: widget.totalPedido,
                              totalReceber:
                                  widget.totalReceber.toStringAsFixed(2),
                              pagamentoselecionado: widget.pagamentoselecionado,
                              vencimentoRecorrente:
                                  widget.recorrencia?.vencimento,
                            ),
                          ),
                        );
                      } else {
                        if (finalizandoValue == true) return;

                        finalizando.value = true;

                        if (provedorCardapio.tipo == TipoCardapio.delivery) {
                          try {
                            await _finalizarDelivery();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text(e is StateError
                                    ? e.message.toString()
                                    : 'Não foi possível finalizar o Delivery. Confira o pedido antes de tentar novamente.'),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ));
                            }
                          } finally {
                            finalizando.value = false;
                          }
                          return;
                        }

                        var (sucesso, mensagem, idvenda) = await context
                            .read<ServicoFinalizarPagamento>()
                            .pagarPedido(
                              provedor.idVenda,
                              provedorCardapio.idComanda,
                              provedorCardapio.idMesa,
                              provedorCardapio.idCliente,
                              _dinheiroController.text, // valorLancamento,
                              widget.totalReceber
                                  .toStringAsFixed(2), // valorOriginal,
                              int.parse(widget.pagamentoselecionado),
                              0, // quantidadePessoas,
                              widget.totalReceber
                                  .toStringAsFixed(2), // subTotal,
                              dataOriginal, // dataLancamento,
                              '0', // parcelas
                              [], // parcelasLista
                              provedorCardapio.tipo,
                              _desconto.abs().toStringAsFixed(2), // valortroco,
                              '0', // TODO: fazer delivery (valorentrega)
                              carrinhoProvedor.itensCarrinho.precoTotal
                                  .toStringAsFixed(2), // valoresProduto,
                              false, // novo,
                              provedorCardapio.tipodeentrega,
                              carrinhoProvedor
                                  .itensCarrinho.listaComandosPedidos,
                              widget.totalReceber
                                  .toStringAsFixed(2), // valorAPagarOriginal,
                              provedorBalcao.observacaoDoPedido,
                            );

                        if (sucesso) {
                          if (idvenda.startsWith('venda-local:')) {
                            await carrinhoProvedor.listarComandasPedidos();
                            finalizando.value = false;
                            if (!context.mounted) return;
                            if ((double.tryParse(_dinheiroController.text) ??
                                    0) >=
                                widget.totalReceber) {
                              provedorBalcao.observacaoDoPedido = '';
                              FeedbackUsuario.pedidoFinalizado();
                              Navigator.popUntil(
                                  context, ModalRoute.withName('PaginaBalcao'));
                            } else {
                              provedor.idVenda = idvenda;
                              provedor.valor = widget.totalReceber -
                                  (double.tryParse(_dinheiroController.text) ??
                                      0);
                              Navigator.popUntil(
                                  context,
                                  ModalRoute.withName(
                                      'PaginaFinalizarAcrescimo'));
                            }
                            return;
                          }
                          provedorBalcao.observacaoDoPedido = '';

                          if (double.parse(_dinheiroController.text) >=
                              widget.totalReceber) {
                            var provedorBalcao = Modular.get<ProvedorBalcao>();
                            var servico = Modular.get<ServicoBalcao>();
                            await provedorBalcao.listar();

                            var vendaBalcao = provedorBalcao.dados
                                .where((element) => element.id == idvenda)
                                .firstOrNull;

                            if (vendaBalcao != null) {
                              server.write(jsonEncode({
                                'tipo': TipoCardapio.balcao.nome,
                                'nomeConexao': usuarioProvedor.usuario!.nome,
                              }));

                              final configuracaoImpressao =
                                  await Modular.get<ServicoConfigBigchef>()
                                      .listar(forcarAtualizacao: true);
                              final imprimirPreparoNoComprovante = configuracaoImpressao
                                      ?.imprimePreparoNoComprovanteConsumacao ??
                                  provedorCardapio.configBigchef
                                      ?.imprimePreparoNoComprovanteConsumacao ??
                                  false;
                              if (configuracaoImpressao != null) {
                                provedorCardapio.configBigchef =
                                    configuracaoImpressao;
                              }

                              if (!imprimirPreparoNoComprovante) {
                                await Impressao.comprovanteDePedido(
                                  local: '',
                                  tipoTela: provedorCardapio.tipo,
                                  comanda: "Balcão $idvenda",
                                  numeroPedido: vendaBalcao.numeropedido,
                                  nomeCliente: ((vendaBalcao.nomecliente) ==
                                                  'Sem Cliente' ||
                                              vendaBalcao.nomecliente == "") &&
                                          (vendaBalcao.observacaoDoPedido ?? '')
                                              .isNotEmpty
                                      ? (vendaBalcao.observacaoDoPedido ?? '')
                                      : (vendaBalcao.nomecliente),
                                  nomeEmpresa: vendaBalcao.nomeEmpresa,
                                  produtos: carrinhoProvedor
                                      .itensCarrinho.listaComandosPedidos,
                                  tipodeentrega: vendaBalcao.idtipodeentrega,
                                );
                              }

                              var informacoes =
                                  await servico.listarPorId(idvenda);
                              var parcelas =
                                  await servico.listarFinanceiroVenda(idvenda);

                              final duration = DateTime.now().difference(
                                  DateTime.parse(vendaBalcao.dataHora));
                              final newDuration =
                                  ConfigSistema.formatarHora(duration);

                              Impressao.comprovanteDeConsumo(
                                tipoTela: TipoCardapio.balcao,
                                agruparPorDestino: false,
                                valorentrega:
                                    informacoes.informacoes.valorentrega,
                                nomeEmpresa: vendaBalcao.nomeEmpresa,
                                produtos: informacoes.produtos,
                                nomelancamento: List<ModeloNomeLancamento>.from(
                                    parcelas.map((elemento) {
                                  return ModeloNomeLancamento(
                                      nome: elemento.entradaMov,
                                      valor: UtilBrasilFields
                                              .converterMoedaParaDouble(
                                                  elemento.valorMovF)
                                          .toStringAsExponential(2));
                                })),
                                somaValorHistorico:
                                    informacoes.informacoes.subtotal,
                                cnpjEmpresa: informacoes.informacoes.docempresa,
                                celularEmpresa:
                                    informacoes.informacoes.celularcliente,
                                enderecoEmpresa:
                                    informacoes.informacoes.enderecoempresa,
                                permanencia: newDuration,
                                local: '',
                                total: informacoes.informacoes.subtotal,
                                numeroPedido:
                                    informacoes.informacoes.numerodopedido,
                                tipodeentrega:
                                    informacoes.informacoes.tipodeentrega,
                                nomeCliente:
                                    (informacoes.informacoes.nomeCliente == ''
                                            ? null
                                            : informacoes
                                                .informacoes.nomeCliente) ??
                                        'Sem Cliente',
                              );
                              FeedbackUsuario.pedidoFinalizado();
                            }

                            carrinhoProvedor.removerComandasPedidos();

                            if (context.mounted) {
                              Navigator.popUntil(
                                  context, ModalRoute.withName('PaginaBalcao'));
                            }
                          } else {
                            if (context.mounted) {
                              provedor.idVenda = idvenda;
                              provedor.valor = widget.totalReceber -
                                  double.parse(_dinheiroController.text);

                              Navigator.popUntil(
                                  context,
                                  ModalRoute.withName(
                                      'PaginaFinalizarAcrescimo'));
                            }
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(mensagem),
                            backgroundColor: Colors.red,
                            behavior: SnackBarBehavior.floating,
                          ));
                        }

                        finalizando.value = false;
                      }
                    },
                    child: Center(
                      child: Visibility(
                        visible: finalizandoValue == false,
                        replacement: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.4, color: Colors.white),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.pagamentoselecionado == '2'
                                  ? Icons.arrow_forward_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              widget.pagamentoselecionado == '2'
                                  ? 'Ir para Parcelamento'
                                  : 'Finalizar',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: _carregando
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned(
                    bottom: 115,
                    left: 14,
                    right: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1F2937) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : cs.outline.withValues(alpha: 0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.fact_check_outlined,
                                  size: 16,
                                  color: cs.onSurface.withValues(alpha: 0.7)),
                              const SizedBox(width: 6),
                              const Text('Total Registrado',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Text(
                            _totalRegistrado.obterReal(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: cs.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 200),
                    children: [
                      // Hero "A pagar"
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cs.primaryContainer,
                              cs.primaryContainer.withValues(alpha: 0.55)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: cs.primary.withValues(alpha: 0.12),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            SearchAnchor(
                              builder: (BuildContext context,
                                  SearchController controller) {
                                return IconButton.filledTonal(
                                  onPressed: () => controller.openView(),
                                  icon: const Icon(Icons.history_rounded,
                                      size: 18),
                                  tooltip: 'Histórico de pagamentos',
                                );
                              },
                              suggestionsBuilder: (BuildContext context,
                                  SearchController controller) async {
                                final res = await Modular.get<ServicoBalcao>()
                                    .listarHistoricoPagamentos(
                                        provedor.idVenda, TipoCardapio.balcao);
                                return [
                                  ...res.map(
                                    (e) => Card(
                                      elevation: 3.0,
                                      margin: const EdgeInsets.all(5.0),
                                      child: InkWell(
                                        onTap: () {},
                                        borderRadius: const BorderRadius.all(
                                            Radius.circular(8)),
                                        child: ListTile(
                                          leading: const Icon(
                                              Icons.person_2_outlined),
                                          title: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(e.pagamento),
                                              Text(
                                                  "Valor ${double.parse(e.valor).obterReal()}"),
                                              Text(
                                                  "Total: ${double.parse(e.somaValorHistorico).obterReal()}"),
                                            ],
                                          ),
                                          subtitle: Text('ID: ${e.id}'),
                                        ),
                                      ),
                                    ),
                                  ),
                                ];
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'A PAGAR',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.4,
                                      color: cs.onPrimaryContainer
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.totalReceber.obterReal(),
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w800,
                                      color: cs.onPrimaryContainer,
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Icon(Icons.attach_money_rounded,
                              size: 18, color: cs.primary),
                          const SizedBox(width: 8),
                          const Text('Valor a receber',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Column(
                        children: [
                          // InformacoesApp.getLogoEscuraApp(context, width: 200, height: 100),
                          // const SizedBox(height: 18),

                          // Row(
                          //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          //   children: [
                          //     Container(
                          //       width: 115,
                          //       height: 120,
                          //       decoration: const BoxDecoration(
                          //         borderRadius: BorderRadius.all(Radius.circular(8)),
                          //         boxShadow: [
                          //           BoxShadow(
                          //             offset: Offset(0, 3),
                          //             blurRadius: 7,
                          //             spreadRadius: 1,
                          //             color: Colors.black54,
                          //           ),
                          //         ],
                          //       ),
                          //       child: Material(
                          //         color: _selecionado == 1
                          //             ? Theme.of(context).brightness == Brightness.light
                          //                 ? Theme.of(context).colorScheme.primary
                          //                 // ? const Color(0xFF4f0073)
                          //                 : Theme.of(context).colorScheme.inversePrimary
                          //             : Theme.of(context).brightness == Brightness.light
                          //                 ? Colors.white
                          //                 : const Color(0xff1c1c1c),
                          //         borderRadius: const BorderRadius.all(Radius.circular(8)),
                          //         child: InkWell(
                          //           onTap: () {
                          //             ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          //             setState(() => _selecionado = 1);
                          //           },
                          //           borderRadius: const BorderRadius.all(Radius.circular(8)),
                          //           child: Column(
                          //             mainAxisAlignment: MainAxisAlignment.center,
                          //             children: [
                          //               Text(
                          //                 'Não Fiscal',
                          //                 style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _selecionado == 1 ? Colors.white : null),
                          //               ),
                          //               const SizedBox(height: 10),
                          //               Icon(Icons.add_shopping_cart, size: 40, color: _selecionado == 1 ? Colors.white : null),
                          //             ],
                          //           ),
                          //         ),
                          //       ),
                          //     ),
                          //     Container(
                          //       width: 115,
                          //       height: 120,
                          //       decoration: const BoxDecoration(
                          //         borderRadius: BorderRadius.all(Radius.circular(8)),
                          //         boxShadow: [
                          //           BoxShadow(
                          //             offset: Offset(0, 3),
                          //             blurRadius: 7,
                          //             spreadRadius: 1,
                          //             color: Colors.black54,
                          //           ),
                          //         ],
                          //       ),
                          //       child: Material(
                          //         color: _selecionado == 2
                          //             ? Theme.of(context).brightness == Brightness.light
                          //                 ? Theme.of(context).colorScheme.primary
                          //                 // ? const Color(0xFF4f0073)
                          //                 : Theme.of(context).colorScheme.inversePrimary
                          //             : Theme.of(context).brightness == Brightness.light
                          //                 ? Colors.white
                          //                 : const Color(0xff1c1c1c),
                          //         borderRadius: const BorderRadius.all(Radius.circular(8)),
                          //         child: InkWell(
                          //           onTap: () {
                          //             ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          //             setState(() => _selecionado = 2);
                          //           },
                          //           borderRadius: const BorderRadius.all(Radius.circular(8)),
                          //           child: Column(
                          //             mainAxisAlignment: MainAxisAlignment.center,
                          //             children: [
                          //               Text(
                          //                 'Emitir NFe',
                          //                 style: TextStyle(
                          //                   fontSize: 16,
                          //                   fontWeight: FontWeight.bold,
                          //                   color: _selecionado == 2 ? Colors.white : null,
                          //                 ),
                          //               ),
                          //               const SizedBox(height: 10),
                          //               Icon(Icons.shopping_cart_outlined, size: 40, color: _selecionado == 2 ? Colors.white : null),
                          //             ],
                          //           ),
                          //         ),
                          //       ),
                          //     ),
                          //     Container(
                          //       width: 115,
                          //       height: 120,
                          //       decoration: const BoxDecoration(
                          //         borderRadius: BorderRadius.all(Radius.circular(8)),
                          //         boxShadow: [
                          //           BoxShadow(
                          //             offset: Offset(0, 3),
                          //             blurRadius: 7,
                          //             spreadRadius: 1,
                          //             color: Colors.black54,
                          //           ),
                          //         ],
                          //       ),
                          //       child: Material(
                          //         color: _selecionado == 3
                          //             ? Theme.of(context).brightness == Brightness.light
                          //                 ? Theme.of(context).colorScheme.primary
                          //                 : Theme.of(context).colorScheme.inversePrimary
                          //             : Theme.of(context).brightness == Brightness.light
                          //                 ? Colors.white
                          //                 : const Color(0xff1c1c1c),
                          //         borderRadius: const BorderRadius.all(Radius.circular(8)),
                          //         child: InkWell(
                          //           onTap: () {
                          //             ScaffoldMessenger.of(context).removeCurrentSnackBar();
                          //             setState(() => _selecionado = 3);
                          //           },
                          //           borderRadius: const BorderRadius.all(Radius.circular(8)),
                          //           child: Column(
                          //             mainAxisAlignment: MainAxisAlignment.center,
                          //             children: [
                          //               Text(
                          //                 'Emitir NFCe',
                          //                 style: TextStyle(
                          //                   fontSize: 16,
                          //                   fontWeight: FontWeight.bold,
                          //                   color: _selecionado == 3 ? Colors.white : null,
                          //                 ),
                          //               ),
                          //               const SizedBox(height: 10),
                          //               Icon(Icons.shopping_cart_checkout_outlined, size: 40, color: _selecionado == 3 ? Colors.white : null),
                          //             ],
                          //           ),
                          //         ),
                          //       ),
                          //     ),
                          //   ],
                          // ),
                          // const Text('Desconto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          // const SizedBox(height: 20),
                          // const Text('Você pode dar desconto em percentual\nou até mesmo em Valor.', style: TextStyle(fontSize: 15), textAlign: TextAlign.center),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _dinheiroController,
                              focusNode: focusNode,
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: cs.primary,
                                letterSpacing: -0.3,
                              ),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark
                                    ? const Color(0xFF1F2937)
                                    : Colors.white,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 14),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color:
                                          cs.outline.withValues(alpha: 0.22)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                      color:
                                          cs.outline.withValues(alpha: 0.22)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide:
                                      BorderSide(color: cs.primary, width: 1.6),
                                ),
                                prefixText: 'R\$  ',
                                prefixStyle: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        cs.onSurface.withValues(alpha: 0.55)),
                                suffixIcon: IconButton(
                                  onPressed: () {
                                    _dinheiroController.clear();
                                    calcular();
                                  },
                                  icon:
                                      const Icon(Icons.close_rounded, size: 20),
                                  splashRadius: 20,
                                ),
                              ),
                              onChanged: (_) => calcular(),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(',',
                                    replacementString: '.'),
                                FilteringTextInputFormatter.allow(
                                    RegExp(r'(^\d*\.?\d{0,2})')),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (_desconto > 0) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.green
                                .withValues(alpha: isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.green.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.savings_outlined,
                                      color: Colors.green[700], size: 22),
                                  const SizedBox(width: 8),
                                  const Text('Troco',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700)),
                                ],
                              ),
                              Text(
                                'R\$ ${_desconto.toStringAsFixed(2).replaceAll('.', ',')}',
                                style: TextStyle(
                                  fontSize: 22,
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setState(() {
                              trocoEmCredito = !trocoEmCredito;
                            });
                          },
                          splashColor: Colors.transparent,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              SizedBox(
                                width: 25,
                                child: Checkbox(
                                  value: trocoEmCredito,
                                  onChanged: (value) {
                                    setState(() {
                                      trocoEmCredito = value ?? false;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text('Troco em Crédito')
                            ],
                          ),
                        ),
                      ],
                      // if (_desconto < 0) ...[
                      //   Row(
                      //     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      //     children: [
                      //       const Text('Falta ', style: TextStyle(fontSize: 25, color: Colors.red)),
                      //       // const Spacer(),
                      //       Text(
                      //         'R\$ ${(_desconto * -1).toStringAsFixed(2).replaceAll('.', ',')}',
                      //         style: const TextStyle(
                      //           fontSize: 25,
                      //           color: Colors.red,
                      //           fontWeight: FontWeight.w600,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ],
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
