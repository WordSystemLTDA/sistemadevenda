import 'package:app/src/modulos/finalizar_pagamento/modelos/parcelas_modelo_pdv.dart';
import 'package:app/src/modulos/finalizar_pagamento/paginas/widgets/bottom_editar_parcelamento.dart';
import 'package:app/src/modulos/finalizar_pagamento/servicos/servico_finalizar_pagamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:intl/intl.dart';

class PaginaParcelamento extends StatefulWidget {
  // final SalvarListarVendasModelo modelo;
  final String idVenda;
  final double valor;
  final String acrescimo;
  final String desconto;
  final String descontoPercentual;
  final String totalPedido;
  final String totalReceber;
  // final String dinheiro;
  // final String promissoria;
  // final String cartaoDebito;
  // final String cartaoCredito;
  final String valorFalta;
  final String valorTroco;

  const PaginaParcelamento({
    super.key,
    required this.idVenda,
    required this.valor,
    required this.acrescimo,
    required this.desconto,
    required this.descontoPercentual,
    required this.totalPedido,
    required this.totalReceber,
    // required this.dinheiro,
    // required this.promissoria,
    // required this.cartaoDebito,
    // required this.cartaoCredito,
    required this.valorFalta,
    required this.valorTroco,
  });

  @override
  State<PaginaParcelamento> createState() => _PaginaParcelamentoState();
}

class _PaginaParcelamentoState extends State<PaginaParcelamento> {
  final _valorController = TextEditingController();

  final _dataController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime.now()));
  String dataOriginal = DateFormat('yyyy-MM-dd').format(DateTime.now());

  final ValueNotifier<bool> finalizando = ValueNotifier(false);
  final ValueNotifier<List<ParcelasModelo>> listaParcelas = ValueNotifier([]);
  int _parcelas = 0;

  final String _idCliente = '';
  final String _nomeCliente = '';
  String _vendaDia1 = '30';
  String _vendaDia2 = '45';
  String _vendaDia3 = '60';
  String _vendaDia4 = '90';

  @override
  void initState() {
    super.initState();

    _valorController.text = widget.valor.toStringAsFixed(2).replaceAll('.', ',');

    alterarParcelas(incrementar: true);
    listarCliente();
    listarDatasVenda();
  }

  void listarDatasVenda() async {
    await context.read<ServicoFinalizarPagamento>().listarDatasVendas().then((value) {
      if (value == null) return;

      setState(() {
        _vendaDia1 = value.vendaDia1;
        _vendaDia2 = value.vendaDia2;
        _vendaDia3 = value.vendaDia3;
        _vendaDia4 = value.vendaDia4;
      });
    });
  }

  void alterarParcelas({required bool incrementar}) {
    if (!incrementar) {
      setState(() => _parcelas = _parcelas - 1);
    } else {
      setState(() => _parcelas = _parcelas + 1);
    }

    List<ParcelasModelo> parcelasNovas = [];

    var dataOriginalF = DateTime.parse(dataOriginal);

    for (var i = 0; i < _parcelas; i++) {
      parcelasNovas.add(ParcelasModelo(
        parcela: (i + 1).toString(),
        valor: widget.valor.toStringAsFixed(2),
        vencimento: DateFormat('yyyy-MM-dd').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day)),
        vencimentoController: TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day))),
        valorController: TextEditingController(
          text: (widget.valor / _parcelas).toStringAsFixed(2),
        ),
      ));
    }

    listaParcelas.value = parcelasNovas;
  }

  void listarCliente() async {
    // final (idCliente, razaoSocialCliente) = await context.read<ProvedoresTelaNfeSaida>().listarCliente(context);
    // if (!mounted) return;

    // setState(() {
    //   _idCliente = idCliente;
    //   _nomeCliente = razaoSocialCliente; // AQUI
    // });
  }

  void finalizar() async {
    finalizando.value = true;
    // final modelo = context.read<ProvedoresTelaNfeSaida>().venda;

    if (!mounted) return;

    // if (modelo == null) {
    //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //     content: Text('Ocorreu um Erro: Não Há Venda'),
    //     backgroundColor: Colors.red,
    //     showCloseIcon: true,
    //   ));
    //   finalizando.value = false;
    //   return;
    // }

    // final (sucesso, mensagem) = await context.read<ServicoFinalizarPagamento>().inserir(
    //       SalvarListarVendasModelo(
    //         idVenda: modelo.idVenda,
    //         idCliente: modelo.idCliente,
    //         razaoSocialCliente: modelo.razaoSocialCliente,
    //         idNatureza: modelo.idNatureza,
    //         idVendedor: modelo.idVendedor,
    //         dataLancamento: modelo.dataLancamento,
    //         idTransportadoraNfe: modelo.idTransportadoraNfe,
    //         fretePorContaNfe: modelo.fretePorContaNfe,
    //         placaDoVeiculoNfe: modelo.placaDoVeiculoNfe,
    //         ufDoVeiculoNfe: modelo.ufDoVeiculoNfe,
    //         quantidadeTransNfe: modelo.quantidadeTransNfe,
    //         especieTransNfe: modelo.especieTransNfe,
    //         marcaTransNfe: modelo.marcaTransNfe,
    //         numeracaoTransNfe: modelo.numeracaoTransNfe,
    //         pesoBrutoTransNfe: modelo.pesoBrutoTransNfe,
    //         pesoLiquidoTransNfe: modelo.pesoLiquidoTransNfe,
    //         tipoNfReferenciadaNfe: modelo.tipoNfReferenciadaNfe,
    //         chaveAcessoNfeRefNfe: modelo.chaveAcessoNfeRefNfe,
    //         descricaoDoCliente: modelo.descricaoDoCliente,
    //         observacoesDoCliente: modelo.observacoesDoCliente,
    //         resumoFinal: modelo.resumoFinal,
    //         observacoesInterna: modelo.observacoesInterna,
    //         dadosAdicionais: modelo.dadosAdicionais,
    //         moviDinheiro: widget.dinheiro,
    //         moviPromissoria: widget.promissoria,
    //         moviCartaoDebito: widget.cartaoDebito,
    //         moviCartaoCredito: widget.cartaoCredito,
    //         moviPix: modelo.moviPix,
    //         moviOp2: modelo.moviOp2,
    //         moviOp3: modelo.moviOp3,
    //         moviOp4: modelo.moviOp4,
    //         moviOp5: modelo.moviOp5,
    //         produtos: modelo.produtos,
    //         acrescimo: widget.acrescimo,
    //         data: dataOriginal,
    //         desconto: widget.desconto,
    //         descontoPercentual: widget.descontoPercentual,
    //         docDePessoa: '',
    //         emissaoDeNota: '',
    //         idDescricao: '',
    //         notaFiscal: '',
    //         parcelas: listaParcelas.value.length.toString(),
    //         parcelasLista: listaParcelas.value,
    //         subTotalNovo: widget.totalPedido,
    //         tipoDePessoa: modelo.tipoDePessoa,
    //         totalAReceber: widget.totalReceber,
    //         totalRecebido: '',
    //         valorFalta: widget.valorFalta,
    //         valorTroco: widget.valorTroco,
    //       ),
    //     );

    if (!mounted) return;

    // if (sucesso) {
    //   if (mounted) {
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //     Navigator.pop(context);
    //   }
    // }

    // if (mounted) {
    //   ScaffoldMessenger.of(context).hideCurrentSnackBar();
    //   ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    //     content: Text(mensagem),
    //     backgroundColor: sucesso ? Colors.green : Colors.red,
    //     showCloseIcon: true,
    //     behavior: SnackBarBehavior.floating,
    //   ));
    // }

    finalizando.value = false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parcelamento'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5)),
        ),
        backgroundColor: DateFormat('yyyy-MM-dd').format(DateTime.parse(dataOriginal)) == DateFormat('yyyy-MM-dd').format(DateTime.now()) ? null : const Color(0xFF4f0073),
        foregroundColor: DateFormat('yyyy-MM-dd').format(DateTime.parse(dataOriginal)) == DateFormat('yyyy-MM-dd').format(DateTime.now()) ? null : Colors.white,
        onPressed: () {
          finalizar();
        },
        label: SizedBox(
          width: MediaQuery.of(context).size.width - 70,
          child: ValueListenableBuilder(
            valueListenable: finalizando,
            builder: (context, finalizandoValue, _) {
              return Visibility(
                visible: finalizandoValue == false,
                replacement: const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  ),
                ),
                child: const Text('Finalizar', textAlign: TextAlign.center),
              );
            },
          ),
        ),
      ),
      resizeToAvoidBottomInset: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 10, right: 10, top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '  ID Cliente: #$_idCliente',
                  style: const TextStyle(fontSize: 14),
                ),
                Row(
                  children: [
                    const Icon(Icons.person_outline_outlined, size: 22),
                    const SizedBox(width: 5),
                    Text(
                      _nomeCliente,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('('),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () {
                        _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: int.parse(_vendaDia1))));
                        dataOriginal = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: int.parse(_vendaDia1))));

                        List<ParcelasModelo> parcelasNovas = [];

                        var dataOriginalF = DateTime.parse(dataOriginal);

                        for (var i = 0; i < _parcelas; i++) {
                          parcelasNovas.add(ParcelasModelo(
                            parcela: (i + 1).toString(),
                            valor: widget.valor.toStringAsFixed(2),
                            vencimento: DateFormat('yyyy-MM-dd').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day)),
                            vencimentoController:
                                TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day))),
                            valorController: TextEditingController(text: (widget.valor / _parcelas).toStringAsFixed(2)),
                          ));
                        }

                        listaParcelas.value = parcelasNovas;

                        setState(() {});
                      },
                      child: Text('$_vendaDia1 dias'),
                    ),
                    const SizedBox(width: 5),
                    const Text('/'),
                    const SizedBox(width: 5),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () {
                        _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: int.parse(_vendaDia2))));
                        dataOriginal = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: int.parse(_vendaDia2))));

                        List<ParcelasModelo> parcelasNovas = [];

                        var dataOriginalF = DateTime.parse(dataOriginal);

                        for (var i = 0; i < _parcelas; i++) {
                          parcelasNovas.add(ParcelasModelo(
                            parcela: (i + 1).toString(),
                            valor: widget.valor.toStringAsFixed(2),
                            vencimento: DateFormat('yyyy-MM-dd').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day)),
                            vencimentoController:
                                TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day))),
                            valorController: TextEditingController(text: (widget.valor / _parcelas).toStringAsFixed(2)),
                          ));
                        }

                        listaParcelas.value = parcelasNovas;
                        setState(() {});
                      },
                      child: Text('$_vendaDia2 dias'),
                    ),
                    const SizedBox(width: 5),
                    const Text('/'),
                    const SizedBox(width: 5),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () {
                        _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: int.parse(_vendaDia3))));
                        dataOriginal = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: int.parse(_vendaDia3))));

                        List<ParcelasModelo> parcelasNovas = [];

                        var dataOriginalF = DateTime.parse(dataOriginal);

                        for (var i = 0; i < _parcelas; i++) {
                          parcelasNovas.add(ParcelasModelo(
                            parcela: (i + 1).toString(),
                            valor: widget.valor.toStringAsFixed(2),
                            vencimento: DateFormat('yyyy-MM-dd').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day)),
                            vencimentoController:
                                TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day))),
                            valorController: TextEditingController(text: (widget.valor / _parcelas).toStringAsFixed(2)),
                          ));
                        }

                        listaParcelas.value = parcelasNovas;
                        setState(() {});
                      },
                      child: Text('$_vendaDia3 dias'),
                    ),
                    const SizedBox(width: 5),
                    const Text('/'),
                    const SizedBox(width: 5),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(50, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: () {
                        _dataController.text = DateFormat('dd/MM/yyyy').format(DateTime.now().add(Duration(days: int.parse(_vendaDia4))));
                        dataOriginal = DateFormat('yyyy-MM-dd').format(DateTime.now().add(Duration(days: int.parse(_vendaDia4))));

                        List<ParcelasModelo> parcelasNovas = [];

                        var dataOriginalF = DateTime.parse(dataOriginal);

                        for (var i = 0; i < _parcelas; i++) {
                          parcelasNovas.add(ParcelasModelo(
                            parcela: (i + 1).toString(),
                            valor: widget.valor.toStringAsFixed(2),
                            vencimento: DateFormat('yyyy-MM-dd').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day)),
                            vencimentoController:
                                TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day))),
                            valorController: TextEditingController(text: (widget.valor / _parcelas).toStringAsFixed(2)),
                          ));
                        }

                        listaParcelas.value = parcelasNovas;
                        setState(() {});
                      },
                      child: Text('$_vendaDia4 dias'),
                    ),
                    const Text(')'),
                  ],
                ),
                TextField(
                  controller: _dataController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    hintText: '',
                    prefixIcon: Icon(Icons.date_range),
                  ),
                  onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                  onTap: () async {
                    final DateTime? time = await showDatePicker(
                      context: context,
                      firstDate: DateTime(1950),
                      lastDate: DateTime(2100),
                      initialDate: dataOriginal.isEmpty ? DateTime.now() : DateTime.parse(dataOriginal),
                    );

                    if (time != null) {
                      _dataController.text = DateFormat('dd/MM/yyyy').format(time).toString();
                      dataOriginal = DateFormat('yyyy-MM-dd').format(time).toString();

                      List<ParcelasModelo> parcelasNovas = [];

                      var dataOriginalF = DateTime.parse(dataOriginal);

                      for (var i = 0; i < _parcelas; i++) {
                        parcelasNovas.add(ParcelasModelo(
                          parcela: (i + 1).toString(),
                          valor: widget.valor.toStringAsFixed(2),
                          vencimento: DateFormat('yyyy-MM-dd').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day)),
                          vencimentoController:
                              TextEditingController(text: DateFormat('dd/MM/yyyy').format(DateTime(dataOriginalF.year, dataOriginalF.month + i, dataOriginalF.day))),
                          valorController: TextEditingController(
                            text: (widget.valor / _parcelas).toStringAsFixed(2),
                          ),
                        ));
                      }

                      listaParcelas.value = parcelasNovas;

                      setState(() {});
                    }
                  },
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
          Expanded(
            // height: 220,
            child: ValueListenableBuilder(
              valueListenable: listaParcelas,
              builder: (context, value, child) => ListView.builder(
                shrinkWrap: true,
                itemCount: value.length,
                padding: const EdgeInsets.only(left: 6, right: 6),
                itemBuilder: (context, index) {
                  final item = value[index];

                  return Card(
                    child: Container(
                      width: 200,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.light ? Colors.black : Colors.white54,
                          width: 0.5,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            showDragHandle: true,
                            builder: (context) => BottomEditarParcelamento(
                              valor: item.valorController?.text ?? '',
                              data: item.vencimentoController?.text ?? '',
                              aoSalvar: (valor, data) {
                                Navigator.pop(context);

                                listaParcelas.value = listaParcelas.value
                                    .asMap()
                                    .map(
                                      (key, value) => key == index
                                          ? MapEntry(
                                              key,
                                              ParcelasModelo(
                                                parcela: (key + 1).toString(),
                                                valor: item.valor,
                                                vencimento: data,
                                                vencimentoController: TextEditingController(
                                                  text: DateFormat('dd/MM/yyyy').format(DateTime.parse(data)),
                                                ),
                                                valorController: TextEditingController(
                                                  text: double.parse(valor.isEmpty ? '0' : valor).toStringAsFixed(2),
                                                ),
                                              ))
                                          : MapEntry(key, value),
                                    )
                                    .values
                                    .toList();
                              },
                            ),
                          );
                        },
                        borderRadius: const BorderRadius.all(Radius.circular(8)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Text('Parcela: ${item.parcela}'),
                                  const Spacer(),
                                  const Text('Vencimento'),
                                ],
                              ),
                              Row(
                                children: [
                                  const Text('Valor: '),
                                  Text(item.valorController?.text.replaceAll('.', ',') ?? ''),
                                  const Spacer(),
                                  Text(item.vencimentoController?.text ?? ''),
                                ],
                              )
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // const Spacer(),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(topLeft: Radius.circular(60), topRight: Radius.circular(60)),
              // color: Theme.of(context).colorScheme.inversePrimary,
              color: Color.fromARGB(255, 237, 232, 246),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: Text(
                    '${_parcelas.toString()} Parcela',
                    style: TextStyle(fontSize: 25, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 30, right: 30, bottom: 15, top: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: const WidgetStatePropertyAll(Colors.white),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    onPressed: _parcelas <= 1 ? null : () => alterarParcelas(incrementar: false),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.remove_circle_outline,
                                            size: 26,
                                            color: Theme.of(context).brightness == Brightness.light
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.inversePrimary,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Remover',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Theme.of(context).brightness == Brightness.light
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.inversePrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    style: ButtonStyle(
                                      backgroundColor: const WidgetStatePropertyAll(Colors.white),
                                      shape: WidgetStatePropertyAll(
                                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    ),
                                    onPressed: () => alterarParcelas(incrementar: true),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.add_circle_outline,
                                            size: 26,
                                            color: Theme.of(context).brightness == Brightness.light
                                                ? Theme.of(context).colorScheme.primary
                                                : Theme.of(context).colorScheme.inversePrimary,
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            'Adicionar',
                                            style: TextStyle(
                                              fontSize: 17,
                                              color: Theme.of(context).brightness == Brightness.light
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.inversePrimary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Center(
                        child: Text(
                          'Valor à ser Parcelado',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          Text(
                            'R\$ ${widget.valor.toStringAsFixed(2).replaceAll('.', ',')}',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
