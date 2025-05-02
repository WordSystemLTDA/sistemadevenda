// ignore_for_file: public_member_api_docs, sort_constructors_first

import 'dart:convert';

import 'package:app/src/essencial/api/socket/server.dart';
import 'package:app/src/essencial/config_sistema.dart';
import 'package:app/src/essencial/provedores/usuario/usuario_provedor.dart';
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
import 'package:brasil_fields/brasil_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaFinalizarFormaPagamento extends StatefulWidget {
  final double totalReceber;
  final double desconto;
  final String acrescimo;
  final String descontoPercentual;
  final String totalPedido;
  final String pagamentoselecionado;

  const PaginaFinalizarFormaPagamento({
    super.key,
    required this.totalReceber,
    required this.desconto,
    required this.acrescimo,
    required this.descontoPercentual,
    required this.totalPedido,
    required this.pagamentoselecionado,
  });

  @override
  State<PaginaFinalizarFormaPagamento> createState() => _PaginaFinalizarFormaPagamentoState();
}

class _PaginaFinalizarFormaPagamentoState extends State<PaginaFinalizarFormaPagamento> {
  final ProvedorFinalizarPagamento provedor = Modular.get<ProvedorFinalizarPagamento>();
  final ProvedorCardapio provedorCardapio = Modular.get<ProvedorCardapio>();
  final ProvedorCarrinho carrinhoProvedor = Modular.get<ProvedorCarrinho>();
  final UsuarioProvedor usuarioProvedor = Modular.get<UsuarioProvedor>();
  final ProvedorBalcao provedorBalcao = Modular.get<ProvedorBalcao>();
  final Server server = Modular.get<Server>();

  final ValueNotifier<List<BancoPixModelo>> listaBancoPix = ValueNotifier([]);
  final ValueNotifier<bool> finalizando = ValueNotifier(false);
  final List<TextEditingController> listaBancosControllers = [];

  final _dinheiroController = TextEditingController();

  String dataOriginal = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));

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
    _dinheiroController.selection = TextSelection(baseOffset: 0, extentOffset: _dinheiroController.text.length);
    listarBancoPix();
  }

  void listarBancoPix() async {
    setState(() => _carregando = true);
    final res = await context.read<ServicoFinalizarPagamento>().listarBancoPix();
    if (!mounted) return;

    res.map((_) => listaBancosControllers.add(TextEditingController())).toList();
    listaBancoPix.value = res;
    if (mounted) return setState(() => _carregando = false);
  }

  void calcular() {
    final double dinheiro = _dinheiroController.text.isEmpty ? 0 : double.parse(_dinheiroController.text);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Método de Pagamento'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      // resizeToAvoidBottomInset: false,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: ValueListenableBuilder(
          valueListenable: finalizando,
          builder: (context, finalizandoValue, _) {
            return FloatingActionButton.extended(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(5)),
              ),
              backgroundColor: _dinheiroController.text.isEmpty ? const Color.fromARGB(255, 237, 232, 246) : null,
              onPressed: () async {
                if (widget.pagamentoselecionado == '2') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PaginaParcelamento(
                        idVenda: provedor.idVenda,
                        valor: double.tryParse(_dinheiroController.text) ?? 0,
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
                        totalReceber: widget.totalReceber.toStringAsFixed(2),
                        pagamentoselecionado: widget.pagamentoselecionado,
                      ),
                    ),
                  );
                } else {
                  if (finalizandoValue == true) return;

                  finalizando.value = true;

                  var (sucesso, mensagem, idvenda) = await context.read<ServicoFinalizarPagamento>().pagarPedido(
                        provedor.idVenda,
                        provedorCardapio.idComanda,
                        provedorCardapio.idMesa,
                        provedorCardapio.idCliente,
                        _dinheiroController.text, // valorLancamento,
                        widget.totalReceber.toStringAsFixed(2), // valorOriginal,
                        int.parse(widget.pagamentoselecionado),
                        0, // quantidadePessoas,
                        widget.totalReceber.toStringAsFixed(2), // subTotal,
                        dataOriginal, // dataLancamento,
                        '0', // parcelas
                        [], // parcelasLista
                        provedorCardapio.tipo,
                        _desconto.abs().toStringAsFixed(2), // valortroco,
                        '0', // TODO: fazer delivery (valorentrega)
                        carrinhoProvedor.itensCarrinho.precoTotal.toStringAsFixed(2), // valoresProduto,
                        false, // novo,
                        provedorCardapio.tipodeentrega,
                        carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                        widget.totalReceber.toStringAsFixed(2), // valorAPagarOriginal,
                        provedorBalcao.observacaoDoPedido,
                      );

                  if (sucesso) {
                    provedorBalcao.observacaoDoPedido = '';

                    if (double.parse(_dinheiroController.text) >= widget.totalReceber) {
                      var provedorBalcao = Modular.get<ProvedorBalcao>();
                      var servico = Modular.get<ServicoBalcao>();
                      await provedorBalcao.listar();

                      var vendaBalcao = provedorBalcao.dados.where((element) => element.id == idvenda).firstOrNull;

                      if (vendaBalcao != null) {
                        server.write(jsonEncode({
                          'tipo': TipoCardapio.balcao.nome,
                          'nomeConexao': usuarioProvedor.usuario!.nome,
                        }));

                        await Impressao.comprovanteDePedido(
                          local: '',
                          tipoTela: provedorCardapio.tipo,
                          comanda: "Balcão $idvenda",
                          numeroPedido: vendaBalcao.numeropedido,
                          // nomeCliente: vendaBalcao.nomecliente,
                          nomeCliente: (vendaBalcao.nomecliente) == 'Sem Cliente' && (vendaBalcao.observacaoDoPedido ?? '').isNotEmpty
                              ? (vendaBalcao.observacaoDoPedido ?? '')
                              : (vendaBalcao.nomecliente),
                          nomeEmpresa: vendaBalcao.nomeEmpresa,
                          produtos: carrinhoProvedor.itensCarrinho.listaComandosPedidos,
                          tipodeentrega: vendaBalcao.idtipodeentrega,
                        );

                        var informacoes = await servico.listarPorId(idvenda);
                        var parcelas = await servico.listarFinanceiroVenda(idvenda);

                        final duration = DateTime.now().difference(DateTime.parse(vendaBalcao.dataHora));
                        final newDuration = ConfigSistema.formatarHora(duration);

                        Impressao.comprovanteDeConsumo(
                          valorentrega: informacoes.informacoes.valorentrega,
                          nomeEmpresa: vendaBalcao.nomeEmpresa,
                          produtos: informacoes.produtos,
                          nomelancamento: List<ModeloNomeLancamento>.from(parcelas.map((elemento) {
                            return ModeloNomeLancamento(nome: elemento.entradaMov, valor: UtilBrasilFields.converterMoedaParaDouble(elemento.valorMovF).toStringAsExponential(2));
                          })),
                          somaValorHistorico: informacoes.informacoes.subtotal,
                          cnpjEmpresa: informacoes.informacoes.docempresa,
                          celularEmpresa: informacoes.informacoes.celularcliente,
                          enderecoEmpresa: informacoes.informacoes.enderecoempresa,
                          permanencia: newDuration,
                          local: '',
                          total: informacoes.informacoes.subtotal,
                          numeroPedido: informacoes.informacoes.numerodopedido,
                          tipodeentrega: informacoes.informacoes.tipodeentrega,
                          nomeCliente: (informacoes.informacoes.nomeCliente == '' ? null : informacoes.informacoes.nomeCliente) ?? 'Sem Cliente',
                        );
                      }

                      carrinhoProvedor.removerComandasPedidos();

                      if (context.mounted) {
                        Navigator.popUntil(context, ModalRoute.withName('PaginaBalcao'));
                      }
                    } else {
                      if (context.mounted) {
                        provedor.idVenda = idvenda;
                        provedor.valor = widget.totalReceber - double.parse(_dinheiroController.text);

                        Navigator.popUntil(context, ModalRoute.withName('PaginaFinalizarAcrescimo'));
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
              label: SizedBox(
                width: MediaQuery.of(context).size.width - 70,
                child: Visibility(
                  visible: finalizandoValue == false,
                  replacement: const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  child: Text(
                    widget.pagamentoselecionado == '2' ? 'Ir para Parcelamento' : 'Finalizar',
                    textAlign: TextAlign.center,
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
                    bottom: 100,
                    left: 18,
                    right: 18,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total Registrado ', style: TextStyle(fontSize: 15)),
                            Text(
                              _totalRegistrado.obterReal(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ListView(
                    padding: const EdgeInsets.only(right: 10, left: 10),
                    children: [
                      const SizedBox(height: 15),
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
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              SearchAnchor(
                                builder: (BuildContext context, SearchController controller) {
                                  return IconButton(
                                    onPressed: () {
                                      controller.openView();
                                    },
                                    icon: const Icon(Icons.menu),
                                  );
                                },
                                suggestionsBuilder: (BuildContext context, SearchController controller) async {
                                  final res = await Modular.get<ServicoBalcao>().listarHistoricoPagamentos(provedor.idVenda, TipoCardapio.balcao);
                                  return [
                                    ...res.map(
                                      (e) => Card(
                                        elevation: 3.0,
                                        margin: const EdgeInsets.all(5.0),
                                        child: InkWell(
                                          onTap: () {},
                                          borderRadius: const BorderRadius.all(Radius.circular(8)),
                                          child: ListTile(
                                            leading: const Icon(Icons.person_2_outlined),
                                            title: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(e.pagamento),
                                                Text("Valor ${double.parse(e.valor).obterReal()}"),
                                                Text("Total: ${double.parse(e.somaValorHistorico).obterReal()}"),
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
                              const Text('A pagar: ', style: TextStyle(fontSize: 25)),
                            ],
                          ),
                          // const Spacer(),
                          Text(
                            widget.totalReceber.obterReal(),
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text('Valor a receber', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 80,
                              child: TextField(
                                maxLines: 3,
                                controller: _dinheiroController,
                                focusNode: focusNode,
                                style: const TextStyle(fontSize: 35),
                                decoration: InputDecoration(
                                  border: const OutlineInputBorder(),
                                  prefixText: 'R\$  ',
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      _dinheiroController.clear();
                                      calcular();
                                    },
                                    icon: const Icon(Icons.close),
                                  ),
                                ),
                                onChanged: (_) => calcular(),
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.deny(',', replacementString: '.'),
                                  FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d{0,2})')),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      if (_desconto > 0) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Troco: ', style: TextStyle(fontSize: 25)),
                            // const Spacer(),
                            Text(
                              'R\$ ${_desconto.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: const TextStyle(
                                fontSize: 25,
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
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
